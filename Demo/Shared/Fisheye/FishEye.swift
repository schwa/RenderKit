import Foundation
import Metal
import MetalKit
import simd
import RenderKit

// swiftlint:disable function_body_length

// NOTE: Do not edit without also editing the swift version
struct Uniforms {
    var lerp: Float
    var phi1: Float
    var phi0: Float
    var lambda0: Float
    var r: Float
    var scale: Float
};

struct FishEyeRemoval {

    var trace = false

    func main(cgImage: CGImage, uniforms: Uniforms) throws -> CGImage {

        let device = MTLCreateSystemDefaultDevice()!

        let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: cgImage.width, height: cgImage.height, mipmapped: false)
        outputTextureDescriptor.storageMode = .shared
        outputTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor)!
        outputTexture.label = "Output"

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        //renderPassDescriptor.depthAttachment


        let vertices: [SIMD2<Float>] = [
            [-1, -1], [1, 1], [1, -1],
            [-1, -1], [-1, 1], [1, 1],
        ]

        let vertexBuffer = vertices.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)!
        }
        vertexBuffer.label = "Positions"

        let textureCoordinates: [SIMD2<Float>] = [
            [0, 1], [1, 0], [1, 1],
            [0, 1], [0, 0], [1, 0],
        ]
        let textureCoordinatesBuffer = textureCoordinates.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)!
        }
        textureCoordinatesBuffer.label = "TextureCoordinates"

        let indices: [UInt16] = [0, 1, 2, 3, 4, 5]
        let indicesBuffer = indices.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)!
        }
        indicesBuffer.label = "Indices"

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb

        guard let library = device.makeDefaultLibrary() else {
            fatalError()
        }
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "fisheyeVertex")!
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fisheyeFragment")!

        guard let vertexAttributes = renderPipelineDescriptor.vertexFunction?.vertexAttributes else {
            fatalError()
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD2<Float>>.stride
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor

        let renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        let texture = try MTKTextureLoader(device: device).newTexture(cgImage: cgImage, options: [
            .origin: MTKTextureLoader.Origin.bottomLeft,
            .SRGB: true,
            .textureStorageMode: MTLStorageMode.shared.rawValue
        ])
        texture.label = "Input"

        let samplerDescriptor = MTLSamplerDescriptor()
        let sampler = device.makeSamplerState(descriptor: samplerDescriptor)!

        let commandQueue = device.makeCommandQueue()!

        var captureScope: MTLCaptureScope?
        if trace {
            let captureManager = MTLCaptureManager.shared()
            captureScope = captureManager.makeCaptureScope(device: device)
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = captureScope
            try captureManager.startCapture(with: captureDescriptor)
            captureScope?.begin()
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

        renderCommandEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(cgImage.width), height: Double(cgImage.height), znear: 0, zfar: 1))
        renderCommandEncoder.setCullMode(.back)

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)

        withUnsafeBytes(of: uniforms) { buffer in
            renderCommandEncoder.setVertexBytes(buffer.baseAddress!, length: buffer.count, index: 2)
            renderCommandEncoder.setFragmentBytes(buffer.baseAddress!, length: buffer.count, index: 2)
        }

        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(textureCoordinatesBuffer, offset: 0, index: 1)

        renderCommandEncoder.setFragmentTexture(texture, index: 0)
        renderCommandEncoder.setFragmentSamplerState(sampler, index: 0)

        renderCommandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indicesBuffer, indexBufferOffset: 0)

        renderCommandEncoder.endEncoding()
        commandBuffer.commit()

        commandBuffer.waitUntilCompleted()

        captureScope?.end()

        return outputTexture.betterBetterCGImage
    }
}
