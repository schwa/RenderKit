import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import RenderKit

struct SimpleSceneRenderPass<Configuration>: RenderPass where Configuration: RenderKitConfiguration {
    var scene: SimpleScene
    var depthStencilState: MTLDepthStencilState?
    var flatShaderRenderPipelineState: MTLRenderPipelineState?
    var panoramaShaderRenderPipelineState: MTLRenderPipelineState?
    var cache = Cache<String, Any>()

    init(scene: SimpleScene) {
        self.scene = scene
    }

    mutating func setup(configuration: inout Configuration.Update) throws {
        logger?.debug("\(#function)")
        guard let device = configuration.device else {
            fatalError("No metal device")
        }

        if depthStencilState == nil {
            depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))
        }

        if flatShaderRenderPipelineState == nil {
            let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
            let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
            let fragmentFunction = library.makeFunction(name: "flatShaderFragmentShader")

            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
            renderPipelineDescriptor.vertexDescriptor = SimpleVertex.vertexDescriptor
            flatShaderRenderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }

        if panoramaShaderRenderPipelineState == nil {
            let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
            let vertexFunction = library.makeFunction(name: "panoramicVertexShader")!
            let constantValues = MTLFunctionConstantValues()
            //constantValues.setConstantValue(<#T##value: UnsafeRawPointer##UnsafeRawPointer#>, type: .ushort, withName: <#T##String#>)

            let fragmentFunction = try library.makeFunction(name: "panoramicFragmentShader", constantValues: constantValues)

            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
            renderPipelineDescriptor.vertexDescriptor = SimpleVertex.vertexDescriptor
            panoramaShaderRenderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }

        // Warm cache
        for model in scene.models {
            cache.insert(key: model.mesh.0, value: try! model.mesh.1(device))
        }

        if let panorama = scene.panorama {
            cache.insert(key: "panorama:mesh", value: try! panorama.mesh(device))
            let loader = MTKTextureLoader(device: device)
            let textures = try panorama.tileTextures.map { try $0(loader) }
            cache.insert(key: "panorama:textures", value: textures)
        }
    }

    mutating func resized(configuration: inout Configuration.Update, size: CGSize) throws {
    }

    func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer) throws {
        guard let renderPassDescriptor = configuration.currentRenderPassDescriptor, let size = configuration.size else {
            fatalError("No current render pass descriptor.")
        }

        let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
        let inverseCameraMatrix = scene.camera.transform.matrix.inverse

        commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
            // Render all models with flatShader
            if !scene.models.isEmpty {
                guard let flatShaderRenderPipelineState, let depthStencilState else {
                    return
                }
                encoder.setDepthStencilState(depthStencilState)
                encoder.setRenderPipelineState(flatShaderRenderPipelineState)
                let modes: [(MTLTriangleFillMode, SIMD4<Float>?)] = [
                    (.fill, nil),
                    (.lines, [1, 1, 1, 1]),
                ]
                encoder.setVertexBytes(of: cameraUniforms, index: 1)
                let lightUniforms = LightUniforms(lightPosition: scene.light.position.translation, lightColor: scene.light.color, lightPower: scene.light.power, ambientLightColor: scene.ambientLightColor)
                encoder.setFragmentBytes(of: lightUniforms, index: 3)
                // TODO: Instancing

                let bucketedModels = scene.models.reduce(into: [:]) { partialResult, model in
                    partialResult[model.mesh.0, default: []].append(model)
                }

                for (meshKey, models) in bucketedModels {
                    encoder.pushDebugGroup("Instanced \(meshKey)")
                    guard let mesh = cache.get(key: meshKey) as? MTKMesh else {
                        fatalError()
                    }
                    encoder.setVertexBuffer(mesh, startingIndex: 0)

                    for (fillMode, color) in modes {
                        let modelUniforms = models.map { model in
                            ModelUniforms(
                                modelViewMatrix: inverseCameraMatrix * model.transform.matrix,
                                modelNormalMatrix: simd_float3x3(truncating: model.transform.matrix.transpose.inverse),
                                color: color ?? model.color
                            )
                        }
                        encoder.setTriangleFillMode(fillMode)
                        encoder.setVertexBytes(of: modelUniforms, index: 2)
                        encoder.draw(mesh, instanceCount: models.count)
                    }
                    encoder.popDebugGroup()
                }
            }

            if let panorama = scene.panorama {
                encoder.pushDebugGroup("Panorama")
                guard let panoramaShaderRenderPipelineState, let depthStencilState else {
                    fatalError()
                }
                encoder.setRenderPipelineState(panoramaShaderRenderPipelineState)
                encoder.setDepthStencilState(depthStencilState)

                guard let mesh = cache.get(key: "panorama:mesh") as? MTKMesh else {
                    fatalError()
                }
                encoder.setVertexBuffer(mesh, startingIndex: 0)
                encoder.setVertexBytes(of: cameraUniforms, index: 1)
                let modelViewMatrix = inverseCameraMatrix * .identity
                encoder.setVertexBytes(of: modelViewMatrix, index: 2)

                encoder.setFragmentBytes(of: panorama.tilesSize, index: 0)

                let textures = (cache.get(key: "panorama:textures") as! [MTLTexture]).map {
                    Optional($0)
                }
                encoder.setFragmentTextures(textures, range: 0..<textures.count)
                encoder.setTriangleFillMode(.fill)

                encoder.draw(mesh)
                encoder.popDebugGroup()
            }
        }
    }
}
