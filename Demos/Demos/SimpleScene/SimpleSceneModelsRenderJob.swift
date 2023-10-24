import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import RenderKit
import Observation
import Everything

class SimpleSceneModelsRenderJob: RenderJob {
    var scene: SimpleScene
    var renderJobs: [any RenderJob] = []

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func setup<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws {
        var renderJobs: [AnyHashable: any RenderJob] = [:]
        for model in scene.models {
            if (model.material as? FlatMaterial) != nil {
                if renderJobs["flat-material"] == nil {
                    let job = FlatMaterialRenderJob(models: scene.models)
                    try job.setup(device: device, configuration: &configuration)
                    renderJobs["flat-material"] = job
                }
            }
            else if (model.material as? UnlitMaterial) != nil {
                if renderJobs["Unlit-material"] == nil {
                    let job = UnlitMaterialRenderJob(models: scene.models)
                    try job.setup(device: device, configuration: &configuration)
                    renderJobs["Unlit-material"] = job
                }
            }
        }
        self.renderJobs = Array(renderJobs.values)
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        for renderJob in renderJobs {
            // TODO: DO NOT LIKE
            if var sceneConsuming = renderJob as? SceneConsuming {
                sceneConsuming.scene = scene
            }
            try renderJob.encode(on: encoder, size: size)
        }
    }
}

// MARK: -

protocol SceneConsuming {
    var scene: SimpleScene? { get set }
}

class FlatMaterialRenderJob: RenderJob, SceneConsuming {
    struct Bindings {
        var vertexBufferIndex: Int = -1
        var vertexCameraUniformsIndex: Int = -1
        var vertexInstancedModelUniformsIndex: Int = -1
        var fragmentLightUniformsIndex: Int = -1
    }
    struct DrawState {
        var renderPipelineState: MTLRenderPipelineState
        var depthStencilState: MTLDepthStencilState
        var bindings: Bindings
    }

    var models: [Model]
    var scene: SimpleScene?
    private var bucketedDrawStates: [AnyHashable: DrawState] = [:]

    init(models: [Model]) {
        self.models = models
    }

    func setup<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
        bucketedDrawStates = try models.reduce(into: [:]) { partialResult, model in
            let key = Pair(model.mesh.id, model.mesh.vertexDescriptor.encodedDescription)
            guard partialResult[key] == nil else {
                return
            }

            let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
            let fragmentFunction = library.makeFunction(name: "flatShaderFragmentShader")!

            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = Names.shared.hashed(hashable: key, pad: 4)
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat

            let descriptor = model.mesh.vertexDescriptor
            renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
            let (renderPipelineState, reflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: [.argumentInfo])

            var bindings = Bindings()
            resolveBindings(reflection: reflection!, bindable: &bindings, [
                (\.vertexBufferIndex, .vertex, "vertexBuffer.0"),
                (\.vertexCameraUniformsIndex, .vertex, "cameraUniforms"),
                (\.vertexInstancedModelUniformsIndex, .vertex, "instancedModelUniforms"),
                (\.fragmentLightUniformsIndex, .fragment, "lightUniforms"),
            ])

            let depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))!
            let drawState = DrawState(renderPipelineState: renderPipelineState, depthStencilState: depthStencilState, bindings: bindings)
            partialResult[key] = drawState
        }
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard !models.isEmpty, let scene else {
            return
        }

        let bucketedModels: [AnyHashable: [Model]] = models.reduce(into: [:]) { partialResult, model in
            let key = Pair(model.mesh.id, model.mesh.vertexDescriptor.encodedDescription)
            partialResult[key, default: []].append(model)
        }

        for (key, drawState) in bucketedDrawStates {
            encoder.withDebugGroup("Instanced Models") {
                encoder.setRenderPipelineState(drawState.renderPipelineState)
                encoder.setDepthStencilState(drawState.depthStencilState)
                let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
                let inverseCameraMatrix = scene.camera.transform.matrix.inverse
                encoder.setVertexBytes(of: cameraUniforms, index: drawState.bindings.vertexCameraUniformsIndex)
                let lightUniforms = LightUniforms(lightPosition: scene.light.position.translation, lightColor: scene.light.color, lightPower: scene.light.power, ambientLightColor: scene.ambientLightColor)
                encoder.setFragmentBytes(of: lightUniforms, index: drawState.bindings.fragmentLightUniformsIndex)

                let models = bucketedModels[key]!

                encoder.withDebugGroup("Instanced \(key)") {
                    let mesh = models.first!.mesh
                    encoder.setVertexBuffers(mesh)
                    let modelUniforms = models.map { model in
                        ModelUniforms(
                            modelViewMatrix: inverseCameraMatrix * model.transform.matrix,
                            modelNormalMatrix: simd_float3x3(truncating: model.transform.matrix.transpose.inverse),
                            color: (model.material as? FlatMaterial)?.baseColorFactor ?? [1, 0, 0, 1]
                        )
                    }
                    encoder.setVertexBytes(of: modelUniforms, index: drawState.bindings.vertexInstancedModelUniformsIndex)
                    encoder.setTriangleFillMode(.fill)
                    encoder.draw(mesh, instanceCount: models.count)
                }
            }
        }
    }
}

class UnlitMaterialRenderJob: RenderJob {
    struct Bindings {
        var vertexBufferIndex: Int = -1
        var vertexCameraIndex: Int = -1
        var vertexModelsIndex: Int = -1
    }
    struct DrawState {
        var renderPipelineState: MTLRenderPipelineState
        var depthStencilState: MTLDepthStencilState
        var bindings: Bindings
    }

    var models: [Model]
    var camera: Camera?
    private var bucketedDrawStates: [AnyHashable: DrawState] = [:]

    init(models: [Model]) {
        self.models = models
    }

    func setup<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
        bucketedDrawStates = try models.reduce(into: [:]) { partialResult, model in
            let key = Pair(model.mesh.id, model.mesh.vertexDescriptor.encodedDescription)
            guard partialResult[key] == nil else {
                return
            }

            let vertexFunction = library.makeFunction(name: "unlitVertexShader")!
            let fragmentFunction = library.makeFunction(name: "unlitFragmentShader")!

            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = Names.shared.hashed(hashable: key, pad: 4)
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat

            let descriptor = model.mesh.vertexDescriptor
            renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
            let (renderPipelineState, reflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: [.argumentInfo])

            var bindings = Bindings()
            resolveBindings(reflection: reflection!, bindable: &bindings, [
                (\.vertexBufferIndex, .vertex, "vertexBuffer.0"),
                (\.vertexCameraIndex, .vertex, "camera"),
                (\.vertexModelsIndex, .vertex, "models"),
            ])

            let depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))!
            let drawState = DrawState(renderPipelineState: renderPipelineState, depthStencilState: depthStencilState, bindings: bindings)
            partialResult[key] = drawState
        }
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard !models.isEmpty, let camera else {
            return
        }

        let bucketedModels: [AnyHashable: [Model]] = models.reduce(into: [:]) { partialResult, model in
            let key = Pair(model.mesh.id, model.mesh.vertexDescriptor.encodedDescription)
            partialResult[key, default: []].append(model)
        }

        for (key, drawState) in bucketedDrawStates {
            encoder.withDebugGroup("Instanced Models") {
                encoder.setRenderPipelineState(drawState.renderPipelineState)
                encoder.setDepthStencilState(drawState.depthStencilState)
                let cameraUniforms = CameraUniforms(projectionMatrix: camera.projection.matrix(viewSize: SIMD2<Float>(size)))
                let inverseCameraMatrix = camera.transform.matrix.inverse
                encoder.setVertexBytes(of: cameraUniforms, index: drawState.bindings.vertexCameraIndex)

                let models = bucketedModels[key]!

                encoder.withDebugGroup("Instanced \(key)") {
                    let mesh = models.first!.mesh
                    encoder.setVertexBuffers(mesh)
                    let modelTransforms = models.map { model in
                        ModelTransforms(
                            modelViewMatrix: inverseCameraMatrix * model.transform.matrix,
                            modelNormalMatrix: simd_float3x3(truncating: model.transform.matrix.transpose.inverse)
                        )
                    }
                    encoder.setVertexBytes(of: modelTransforms, index: drawState.bindings.vertexModelsIndex)
                    encoder.setTriangleFillMode(.fill)
                    encoder.draw(mesh, instanceCount: models.count)
                }
            }
        }
    }
}
