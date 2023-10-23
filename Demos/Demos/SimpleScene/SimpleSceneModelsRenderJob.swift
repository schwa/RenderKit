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
    typealias Parameter = (SimpleScene)

    struct Bindings {
        var vertexBufferIndex: Int
        var vertexCameraUniformsIndex: Int
        var vertexInstancedModelUniformsIndex: Int
        var fragmentLightUniformsIndex: Int
    }
    struct DrawState <T> {
        var key: AnyHashable
        var renderPipelineState: MTLRenderPipelineState
        var depthStencilState: MTLDepthStencilState
        var bindings: T
    }

    var scene: SimpleScene
    var cache = Cache<String, Any>()
    var bucketedDrawStates: [AnyHashable: DrawState<Bindings>] = [:]

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func prepare(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)

        print("START **********************")
        bucketedDrawStates = try scene.models.reduce(into: [:]) { partialResult, model in
            let key = Pair(model.mesh.id, model.mesh.vertexDescriptor.encodedDescription)
            guard partialResult[key] == nil else {
                return
            }

            let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
            let fragmentFunction = library.makeFunction(name: "flatShaderFragmentShader")!

            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = Names.shared.hashed(hashable: key, pad: 4)
            print(renderPipelineDescriptor.label)
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat

            let descriptor = model.mesh.vertexDescriptor
            renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
            let (renderPipelineState, reflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: [.argumentInfo])

            var bindings = Bindings(vertexBufferIndex: 0, vertexCameraUniformsIndex: 0, vertexInstancedModelUniformsIndex: 0, fragmentLightUniformsIndex: 0)
            resolveBindings(reflection: reflection!, bindable: &bindings, [
                (\.vertexBufferIndex, .vertex, "vertexBuffer.0"),
                (\.vertexCameraUniformsIndex, .vertex, "cameraUniforms"),
                (\.vertexInstancedModelUniformsIndex, .vertex, "instancedModelUniforms"),
                (\.fragmentLightUniformsIndex, .fragment, "lightUniforms"),
            ])

            let depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))!
            let drawState = DrawState(key: key, renderPipelineState: renderPipelineState, depthStencilState: depthStencilState, bindings: bindings)
            partialResult[key] = drawState
        }
        print("END *********************************")
        print(bucketedDrawStates.count)
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard !scene.models.isEmpty else {
            return
        }

        let bucketedModels: [AnyHashable: [Model]] = scene.models.reduce(into: [:]) { partialResult, model in
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
                            encoder.setVertexBytes(of: modelUniforms, index: drawState.bindings.vertexInstancedModelUniformsIndex)
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

struct Pair <LHS, RHS> {
    var lhs: LHS
    var rhs: RHS

    init(_ lhs: LHS, _ rhs: RHS) {
        self.lhs = lhs
        self.rhs = rhs
    }

    init(_ value: (LHS, RHS)) {
        self.lhs = value.0
        self.rhs = value.1
    }
}

extension Pair: Equatable where LHS: Equatable, RHS: Equatable {
}

extension Pair: Hashable where LHS: Hashable, RHS: Hashable {
}
