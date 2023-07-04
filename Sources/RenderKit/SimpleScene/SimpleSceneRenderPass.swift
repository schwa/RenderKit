import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import Shaders

struct SimpleSceneRenderPass<UpdateConfiguration, DrawConfiguration>: RenderPass where UpdateConfiguration: RenderKitUpdateConfiguration, DrawConfiguration: RenderKitDrawConfiguration {

    var scene: SimpleScene?
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?

    init() {
    }

    mutating func setup(configuration: inout UpdateConfiguration) {
        guard let device = configuration.device else {
            fatalError("No metal device")
        }

        if renderPipelineState == nil {
            let library = try! device.makeDefaultLibrary(bundle: .shaders)
            let constants = MTLFunctionConstantValues()
            let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
            let fragmentFunction = try! library.makeFunction(name: "flatShaderFragmentShader", constantValues: constants)

            // TODO: This is silly...
            let plane = try! MTKMesh(mesh: Plane().toMDLMesh(extent: [2, 2, 0], allocator: MTKMeshBufferAllocator(device: device)), device: device)

            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
            renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(plane.vertexDescriptor)
            renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }

        if depthStencilState == nil {
            let depthStencilDescriptor = MTLDepthStencilDescriptor()
            depthStencilDescriptor.depthCompareFunction = .lessEqual
            depthStencilDescriptor.isDepthWriteEnabled = true
            depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        }
    }

    func draw(configuration: DrawConfiguration, commandBuffer: MTLCommandBuffer) {
        guard let renderPipelineState, let depthStencilState else {

            return
        }
        guard let renderPassDescriptor = configuration.currentRenderPassDescriptor, let size = configuration.size else {
            fatalError("No current render pass descriptor.")
            return
        }
        commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setDepthStencilState(depthStencilState)

            guard let scene else {
                return
            }

            let modes: [(MTLTriangleFillMode, SIMD4<Float>?)] = [
                (.fill, nil),
                (.lines, [1, 1, 1, 1]),
            ]

            let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
            encoder.setVertexBytes(of: cameraUniforms, index: 1)

//            struct LightUniforms {
//                var lightPosition: SIMD3<Float>
//                var lightColor: SIMD3<Float>
//                var lightPower: Float
//                var ambientLightColor: SIMD3<Float>
//
//                // TODO: make a macro of this!
//                var b: [UInt8] {
//                    var result: [UInt8] = []
//                    result.append(contentsOf: bytes(of: lightPosition), alignment: 4)
//                    result.append(contentsOf: bytes(of: lightColor), alignment: 4)
//                    result.append(contentsOf: bytes(of: lightPower), alignment: 4)
//                    result.append(contentsOf: bytes(of: ambientLightColor), alignment: 4)
//                    result.append(contentsOf: Array(repeating: 0, count: 12), alignment: 4)
//                    return result
//                }
//            }


            let lightUniforms = LightUniforms(lightPosition: scene.light.position.translation, lightColor: scene.light.color, lightPower: scene.light.power, ambientLightColor: scene.ambientLightColor)
            encoder.setFragmentBytes(of: lightUniforms, index: 3)

            for model in scene.models {
                encoder.setVertexBuffer(model.mesh, startingIndex: 0)
                for (fillMode, color) in modes {
                    let modelUniforms = ModelUniforms(
                        modelViewMatrix: scene.camera.transform.matrix.inverse * model.transform.matrix,
                        modelNormalMatrix: simd_float3x3(truncating: model.transform.matrix.transpose.inverse),
                        color: color ?? model.color
                    )
                    encoder.setTriangleFillMode(fillMode)

                    encoder.setVertexBytes(of: modelUniforms, index: 2)

                    encoder.draw(model.mesh)
                }
            }
        }
    }
}
