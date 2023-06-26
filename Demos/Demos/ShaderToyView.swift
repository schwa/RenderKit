import SwiftUI
import MetalKit
import ModelIO
import simd
import Everything

struct ShaderToyView: View {

    @State
    var commandQueue: MTLCommandQueue?

    @State
    var shaderToyRenderPipelineState: MTLRenderPipelineState?

    @State
    var plane: MTKMesh?

    @State
    var floorXY = true

    @State
    var scale = SIMD2<Float>(16, 16)

    let start = Date.now
    let speed = Float(51)

    var time: Float {
        return Float(Date.now.timeIntervalSince(start)) * speed
    }

    var body: some View {
        MetalView2 { configuration in
            Task {
                logger.debug("\(String(describing: type(of: self)), privacy: .public).setup")
                //            configuration.colorPixelFormat = .bgra10_xr_srgb
                //            configuration.clearColor = MTLClearColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
                configuration.preferredFramesPerSecond = 120
                guard let device = configuration.device else {
                    fatalError()
                }
                guard let library = device.makeDefaultLibrary() else {
                    fatalError()
                }
            print(self.floorXY)
            let constants = MTLFunctionConstantValues()
            constants.setConstantValue(bytes(of: self.floorXY), type: .bool, index: 0)

            let vertexFunction = library.makeFunction(name: "shaderToyVertexShader")!
            let fragmentFunction = try! library.makeFunction(name: "shaderToyFragmentShader", constantValues: constants)
            let plane = try! MTKMesh(mesh: Plane().toMDLMesh(extent: [2, 2, 0], allocator: MTKMeshBufferAllocator(device: device)), device: device)
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = "shaderToy"
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
                fatalError()
            }
            commandQueue.withCommandBuffer(drawable: configuration.currentDrawable) { commandBuffer in
                guard let renderPassDescriptor = configuration.currentRenderPassDescriptor else {
                    fatalError()
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
                Toggle("Floor", isOn: $floorXY)
            }
            .frame(maxWidth: 120)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.8)))
            .padding()
        }
    }
}

func bytes <T>(of value: T) -> [UInt8] {
    withUnsafeBytes(of: value) { return Array($0) }
}

protocol Shape3D {
    func toMDLMesh(extent: SIMD3<Float>, allocator: MDLMeshBufferAllocator?) -> MDLMesh
}

struct Plane: Shape3D {
    func toMDLMesh(extent: SIMD3<Float>, allocator: MDLMeshBufferAllocator?) -> MDLMesh {
        MDLMesh(planeWithExtent: extent, segments: [1,1], geometryType: .triangles, allocator: allocator)
    }
}

extension MTLCommandQueue {
    func withCommandBuffer<R>(drawable: @autoclosure () -> (any MTLDrawable)?, block: (MTLCommandBuffer) throws -> R) rethrows -> R {
        guard let commandBuffer = makeCommandBuffer() else {
            fatalError()
        }
        defer {
            if let drawable = drawable() {
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }
        return try block(commandBuffer)
    }
}

extension MTLCommandBuffer {
    func withRenderCommandEncoder<R>(descriptor: MTLRenderPassDescriptor, block: (MTLRenderCommandEncoder) throws -> R) rethrows -> R{
        guard let renderCommandEncoder = makeRenderCommandEncoder(descriptor: descriptor) else {
            fatalError()
        }
        defer {
            renderCommandEncoder.endEncoding()
        }
        return try block(renderCommandEncoder)
    }
}

extension MTLRenderCommandEncoder {
    func draw(_ mesh: MTKMesh) {
        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
        }
        for submesh in mesh.submeshes {
            drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
}
