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

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func prepare(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
        let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
        let fragmentFunction = library.makeFunction(name: "flatShaderFragmentShader")

        depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat

        let descriptor = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        // Warm cache
        for model in scene.models {
            cache.insert(key: model.mesh.0, value: try! model.mesh.1(device))
        }
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard !scene.models.isEmpty else {
            return
        }
        guard let renderPipelineState, let depthStencilState else {
            return
        }
        encoder.withDebugGroup("Instanced Models") {
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setDepthStencilState(depthStencilState)
            let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
            let inverseCameraMatrix = scene.camera.transform.matrix.inverse
            encoder.setVertexBytes(of: cameraUniforms, index: 1)
            let lightUniforms = LightUniforms(lightPosition: scene.light.position.translation, lightColor: scene.light.color, lightPower: scene.light.power, ambientLightColor: scene.ambientLightColor)
            encoder.setFragmentBytes(of: lightUniforms, index: 3)

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
                            encoder.setVertexBytes(of: modelUniforms, index: 2)
                            encoder.setTriangleFillMode(fillMode)
                            encoder.draw(mesh, instanceCount: models.count)
                        }
                    }
                }
            }
        }
    }
}

class PanoramaRenderJob <Configuration>: SimpleRenderJob where Configuration: MetalConfiguration {
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var mesh: YAMesh?

    var scene: SimpleScene
    var textures: [MTLTexture] = []

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func prepare(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
        let vertexFunction = library.makeFunction(name: "panoramicVertexShader")!
        let constantValues = MTLFunctionConstantValues()
        //constantValues.setConstantValue(<#T##value: UnsafeRawPointer##UnsafeRawPointer#>, type: .ushort, withName: <#T##String#>)

        let fragmentFunction = try library.makeFunction(name: "panoramicFragmentShader", constantValues: constantValues)

        depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor.always())

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
        let descriptor = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        if let panorama = scene.panorama {
            mesh = try! panorama.mesh(device)
            let loader = MTKTextureLoader(device: device)
            textures = try panorama.tileTextures.map { try $0(loader) }
        }
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard let renderPipelineState, let depthStencilState else {
            return
        }
        guard let panorama = scene.panorama else {
            return
        }
        encoder.withDebugGroup("Panorama") {
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setDepthStencilState(depthStencilState)

            guard let mesh else {
                fatalError()
            }
            encoder.setVertexBuffers(mesh)
            let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
            let inverseCameraMatrix = scene.camera.transform.matrix.inverse
            encoder.setVertexBytes(of: cameraUniforms, index: 1)
            let modelViewMatrix = inverseCameraMatrix * float4x4.translation(scene.camera.transform.translation)
            encoder.setVertexBytes(of: modelViewMatrix, index: 2)

            let uniforms = PanoramaFragmentUniforms(gridSize: panorama.tilesSize, colorFactor: [1, 1, 1, 1])

            encoder.setFragmentBytes(of: uniforms, index: 0)

            encoder.setFragmentTextures(textures, range: 0..<textures.count)
            //encoder.setTriangleFillMode(.fill)

            encoder.draw(mesh)
        }
    }
}
