#if !os(visionOS)
import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import RenderKit

extension SimpleSceneRenderPass: CustomStringConvertible {
    var description: String {
        return "SimpleSceneRenderPass(\(id), depthStencilState: \(depthStencilState != nil), nilDepthStencilState: \(nilDepthStencilState != nil), flatShaderRenderPipelineState: \(flatShaderRenderPipelineState != nil), panoramaShaderRenderPipelineState: \(panoramaShaderRenderPipelineState != nil))"
    }
}

class SimpleSceneRenderPass: RenderPass {
    var id = LOLID2(prefix: "SimpleSceneRenderPass")
    var scene: SimpleScene
    var depthStencilState: MTLDepthStencilState?
    var nilDepthStencilState: MTLDepthStencilState? {
        didSet {
            print(#function, nilDepthStencilState != nil)
        }
    }
    var flatShaderRenderPipelineState: MTLRenderPipelineState?
    var panoramaShaderRenderPipelineState: MTLRenderPipelineState?
    var cache = Cache<String, Any>()

    init(scene: SimpleScene) {
        print("\(id): \(#function)")
        self.scene = scene
    }

    func setup(device: MTLDevice, configuration: inout MetalView.Configuration) throws {
        print("\(id): \(#function)")

        if depthStencilState == nil {
            depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor(depthCompareFunction: .lessEqual, isDepthWriteEnabled: true))
        }

        if nilDepthStencilState == nil {
            nilDepthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor())
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

    func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws {
        print("\(id): \(#function)")
    }

    func draw(device: MTLDevice, configuration: Configuration, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws {
        once(#function) {
            print("\(id): \(#function)")
        }
        let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
        let inverseCameraMatrix = scene.camera.transform.matrix.inverse

        commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
            if let panorama = scene.panorama {
                encoder.withDebugGroup("Panorama") {
                    guard let panoramaShaderRenderPipelineState, let nilDepthStencilState else {
                        once("xyz") {
                            print("No panoramaShaderRenderPipelineState/nilDepthStencilState")
                        }
                        return
                    }
                    encoder.setRenderPipelineState(panoramaShaderRenderPipelineState)
                    encoder.setDepthStencilState(nilDepthStencilState)

                    guard let mesh = cache.get(key: "panorama:mesh") as? MTKMesh else {
                        fatalError()
                    }
                    encoder.setVertexBuffer(mesh, startingIndex: 0)
                    encoder.setVertexBytes(of: cameraUniforms, index: 1)
                    let modelViewMatrix = inverseCameraMatrix * float4x4.translation(scene.camera.transform.translation)
                    encoder.setVertexBytes(of: modelViewMatrix, index: 2)

                    let uniforms = PanoramaFragmentUniforms(gridSize: panorama.tilesSize, colorFactor: [1, 1, 1, 1])

                    encoder.setFragmentBytes(of: uniforms, index: 0)

                    let textures = (cache.get(key: "panorama:textures") as! [MTLTexture]).map {
                        Optional($0)
                    }
                    encoder.setFragmentTextures(textures, range: 0..<textures.count)
                    //encoder.setTriangleFillMode(.fill)

                    encoder.draw(mesh)
                }
            }

            // Render all models with flatShader
            encoder.withDebugGroup("Scene Models") {
                if !scene.models.isEmpty {
                    guard let flatShaderRenderPipelineState, let depthStencilState else {
                        return
                    }
                    encoder.setDepthStencilState(depthStencilState)
                    encoder.setRenderPipelineState(flatShaderRenderPipelineState)
                    encoder.setVertexBytes(of: cameraUniforms, index: 1)
                    let lightUniforms = LightUniforms(lightPosition: scene.light.position.translation, lightColor: scene.light.color, lightPower: scene.light.power, ambientLightColor: scene.ambientLightColor)
                    encoder.setFragmentBytes(of: lightUniforms, index: 3)

                    let bucketedModels = scene.models.reduce(into: [:]) { partialResult, model in
                        partialResult[model.mesh.0, default: []].append(model)
                    }

                    for (meshKey, models) in bucketedModels {
                        encoder.withDebugGroup("Instanced \(meshKey)") {
                            guard let mesh = cache.get(key: meshKey) as? MTKMesh else {
                                fatalError()
                            }
                            encoder.setVertexBuffer(mesh, startingIndex: 0)

                            let modes: [(MTLTriangleFillMode, SIMD4<Float>?)] = [
                                (.fill, nil),
                                (.lines, [1, 1, 1, 1]),
                            ]
                            for (fillMode, color) in modes {
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
    }
}
#endif // !os(visionOS)
