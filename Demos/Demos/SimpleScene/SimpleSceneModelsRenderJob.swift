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
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?

    typealias Parameter = (SimpleScene)

    var scene: SimpleScene
    var cache = Cache<String, Any>()

    struct Bindings {
        var vertexBufferIndex: Int
        var vertexCameraUniformsIndex: Int
        var vertexInstancedModelUniformsIndex: Int
        var fragmentLightUniformsIndex: Int
    }
    var bindings: Bindings?

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func prepare(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)

        // Warm cache
        for model in scene.models {
            let key = model.mesh.0
            let mesh = try model.mesh.1(device)
            print("*********")
            print(key)
            print(mesh.vertexDescriptor.encodedDescription)

            cache.insert(key: key, value: mesh)
        }

        let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
        let fragmentFunction = library.makeFunction(name: "flatShaderFragmentShader")!

//        print(vertexFunction.vertexAttributes)
//        print(vertexFunction.stageInputAttributes)
//        print(fragmentFunction.vertexAttributes)
//        print(fragmentFunction.stageInputAttributes)

        depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat

        let descriptor = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
        let reflection: MTLRenderPipelineReflection?
        (renderPipelineState, reflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: [.argumentInfo])

        var bindings = Bindings(vertexBufferIndex: 0, vertexCameraUniformsIndex: 0, vertexInstancedModelUniformsIndex: 0, fragmentLightUniformsIndex: 0)
        resolveBindings(reflection: reflection!, bindable: &bindings, [
            (\.vertexBufferIndex, .vertex, "vertexBuffer.0"),
            (\.vertexCameraUniformsIndex, .vertex, "cameraUniforms"),
            (\.vertexInstancedModelUniformsIndex, .vertex, "instancedModelUniforms"),
            (\.fragmentLightUniformsIndex, .fragment, "lightUniforms"),
        ])
        self.bindings = bindings
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard !scene.models.isEmpty else {
            return
        }
        guard let renderPipelineState, let depthStencilState, let bindings else {
            return
        }
        encoder.withDebugGroup("Instanced Models") {
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setDepthStencilState(depthStencilState)
            let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
            let inverseCameraMatrix = scene.camera.transform.matrix.inverse
            encoder.setVertexBytes(of: cameraUniforms, index: bindings.vertexCameraUniformsIndex)
            let lightUniforms = LightUniforms(lightPosition: scene.light.position.translation, lightColor: scene.light.color, lightPower: scene.light.power, ambientLightColor: scene.ambientLightColor)
            encoder.setFragmentBytes(of: lightUniforms, index: bindings.fragmentLightUniformsIndex)

            let bucketedModels = scene.models.reduce(into: [:]) { partialResult, model in
                partialResult[model.mesh.0, default: []].append(model)
            }

            for (meshKey, models) in bucketedModels {
                encoder.withDebugGroup("Instanced \(meshKey)") {
                    guard let mesh = cache.get(key: meshKey) as? YAMesh else {
                        fatalError()
                    }
                    encoder.setVertexBuffers(mesh)
                    let modes: [(MTLTriangleFillMode, SIMD4<Float>?)] = [
                        (.fill, nil),
                        (.lines, [1, 1, 1, 1]),
                    ]
                    for (fillMode, color) in modes {
                        //print(meshKey, models)
                        encoder.withDebugGroup("FillMode: \(fillMode))") {
                            let modelUniforms = models.map { model in
                                ModelUniforms(
                                    modelViewMatrix: inverseCameraMatrix * model.transform.matrix,
                                    modelNormalMatrix: simd_float3x3(truncating: model.transform.matrix.transpose.inverse),
                                    color: color ?? model.color
                                )
                            }
                            encoder.setVertexBytes(of: modelUniforms, index: bindings.vertexInstancedModelUniformsIndex)
                            encoder.setTriangleFillMode(fillMode)
                            encoder.draw(mesh, instanceCount: models.count)
                        }
                    }
                }
            }
        }
    }
}

//struct Binding {
//    var shaderType: ShaderType
//    var type: MTLBindingType
//    var name: String
//    var index: Int
//}

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
