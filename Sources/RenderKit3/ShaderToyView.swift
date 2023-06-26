import SwiftUI
import MetalKit
import ModelIO
import simd
import Everything
import MetalSupport

public struct ShaderToyView: View {
    @State
    var commandQueue: MTLCommandQueue?

    @State
    var shaderToyRenderPipelineState: MTLRenderPipelineState?

    @State
    var plane: MTKMesh?

    @State
    var pixelate = true

    @State
    var scale = SIMD2<Float>(16, 16)

    @State
    var speed = Float(1)

    let start = Date.now

    var time: Float {
        return Float(Date.now.timeIntervalSince(start)) * speed
    }

    public init() {
    }

    public var body: some View {
        MetalView2 { configuration in
            Task {
                configuration.preferredFramesPerSecond = 120
                configuration.colorPixelFormat = .bgra10_xr_srgb
                print((configuration as! MTKView).betterDebugDescription)
                guard let device = configuration.device else {
                    fatalError("No metal device")
                }
                let library = try! device.makeDefaultLibrary(bundle: .module)
                let constants = MTLFunctionConstantValues()
                constants.setConstantValue(bytes(of: pixelate), type: .bool, index: 0)

                let vertexFunction = library.makeFunction(name: "shaderToyVertexShader")!
                let fragmentFunction = try! library.makeFunction(name: "shaderToyFragmentShader", constantValues: constants)
                let plane = try! MTKMesh(mesh: Plane().toMDLMesh(extent: [2, 2, 0], allocator: MTKMeshBufferAllocator(device: device)), device: device)
                let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
                renderPipelineDescriptor.vertexFunction = vertexFunction
                renderPipelineDescriptor.fragmentFunction = fragmentFunction
                renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
                renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
                renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(plane.vertexDescriptor)
                let commandQueue = device.makeCommandQueue()
                let shaderToyRenderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
                self.plane = plane
                self.commandQueue = commandQueue
                self.shaderToyRenderPipelineState = shaderToyRenderPipelineState
            }
        }
        draw: { configuration in
//            logger.debug("\(String(describing: type(of: self)), privacy: .public).draw")
            guard let commandQueue, let plane, let shaderToyRenderPipelineState else {
                logger.warning("Not ready to draw.")
                return
            }
            commandQueue.withCommandBuffer(drawable: configuration.currentDrawable) { commandBuffer in
                guard let renderPassDescriptor = configuration.currentRenderPassDescriptor else {
                    logger.warning("No current render pass descriptor.")
                    return
                }
                commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
                    encoder.setRenderPipelineState(shaderToyRenderPipelineState)

                    encoder.setVertexBytes(of: simd_float4x3.identity, index: 1)

                    var fragmentUniforms: [UInt8] = []
                    fragmentUniforms.append(contentsOf: bytes(of: time), alignment: 8)
                    fragmentUniforms.append(contentsOf: bytes(of: 1 / scale), alignment: 8)
                    encoder.setFragmentBytes(fragmentUniforms, length: fragmentUniforms.count, index: 2)

                    encoder.draw(plane)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Form {
                TextField("Scale 1/X", value: $scale.x, format: .number)
                TextField("Scale 1/Y", value: $scale.y, format: .number)
                TextField("Speed", value: $speed, format: .number)
                Toggle("Pixelate", isOn: $pixelate)
            }
            .frame(maxWidth: 120)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.8)))
            .padding()
        }
    }
}
