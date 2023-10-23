import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import RenderKit
import Observation
import Everything

class SimpleSceneModelsRenderJob <Configuration>: SimpleRenderJob where Configuration: MetalConfiguration {
    var scene: SimpleScene
    var renderJobs: [UnlitMaterialRenderJob<Configuration>] = []

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func prepare(device: MTLDevice, configuration: inout Configuration) throws {
        var renderJobs: [AnyHashable: UnlitMaterialRenderJob<Configuration>] = [:]
        for model in scene.models {
            if (model.material as? UnlitMaterial) != nil {
                if renderJobs["unlit-material"] == nil {
                    let job = UnlitMaterialRenderJob<Configuration>(models: scene.models)
                    try job.prepare(device: device, configuration: &configuration)
                    renderJobs["unlit-material"] = job
                }
            }
        }
        self.renderJobs = Array(renderJobs.values)
        print(self.renderJobs)
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        for renderJob in renderJobs {
            renderJob.camera = scene.camera
            renderJob.ambientLightColor = scene.ambientLightColor
            renderJob.light = scene.light
            try renderJob.encode(on: encoder, size: size)
        }
    }
}

// MARK: -

class UnlitMaterialRenderJob <Configuration>: SimpleRenderJob where Configuration: MetalConfiguration {
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
    var camera: Camera?
    var light: Light?
    var ambientLightColor: SIMD3<Float>?
    private var bucketedDrawStates: [AnyHashable: DrawState] = [:]

    init(models: [Model]) {
        self.models = models
    }

    func prepare(device: MTLDevice, configuration: inout Configuration) throws {
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
        print(bucketedDrawStates.count)
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard !models.isEmpty, let camera, let light, let ambientLightColor else {
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
                encoder.setVertexBytes(of: cameraUniforms, index: drawState.bindings.vertexCameraUniformsIndex)
                let lightUniforms = LightUniforms(lightPosition: light.position.translation, lightColor: light.color, lightPower: light.power, ambientLightColor: ambientLightColor)
                encoder.setFragmentBytes(of: lightUniforms, index: drawState.bindings.fragmentLightUniformsIndex)

                let models = bucketedModels[key]!

                encoder.withDebugGroup("Instanced \(key)") {
                    let mesh = models.first!.mesh
                    encoder.setVertexBuffers(mesh)
                    let modelUniforms = models.map { model in
                        ModelUniforms(
                            modelViewMatrix: inverseCameraMatrix * model.transform.matrix,
                            modelNormalMatrix: simd_float3x3(truncating: model.transform.matrix.transpose.inverse),
                            color: (model.material as? UnlitMaterial)?.baseColorFactor ?? [1, 0, 0, 1]
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

func resolveBindings <Bindable>(reflection: MTLRenderPipelineReflection, bindable: inout Bindable, _ a: [(WritableKeyPath<Bindable, Int>, MTLFunctionType, String)]) {
    for (keyPath, shaderType, name) in a {
        switch shaderType {
        case .vertex:
            let binding = reflection.vertexBindings.first(where: { $0.name == name })!
            bindable[keyPath: keyPath] = binding.index
        case .fragment:
            let binding = reflection.fragmentBindings.first(where: { $0.name == name })!
            bindable[keyPath: keyPath] = binding.index
        default:
            fatalError()
        }
    }
}
