import Everything
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders

// TODO: Rename to blitter

open class TextureSubrenderer: Subrenderer {
    public var texture: MTLTexture?

    let quadSize: CGSize
    let vertices: [VertexBasicX]

    public init(device: MTLDevice, quadSize: CGSize) throws {
        self.quadSize = quadSize

        let (w, h) = (Float(quadSize.width) * 0.5, Float(quadSize.height) * 0.5)
        vertices = [
            VertexBasicX(position: [-w, -h], textureCoords: [0, 1]),
            VertexBasicX(position: [w, -h], textureCoords: [1, 1]),
            VertexBasicX(position: [-w, h], textureCoords: [0, 0]),
            VertexBasicX(position: [w, h], textureCoords: [1, 0]),
        ]
    }

    open func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let mtlLibrary = try renderer.device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let vertexFunction = mtlLibrary.makeFunction(name: "pixelBufferVertexShader")
        renderPipelineDescriptor.vertexFunction = vertexFunction

        var builder = VertexDescriptorBuilder()
        builder.addAttribute(format: .float2, size: 8) // size of packed float2
        builder.addAttribute(format: .float2, size: 8) // size of packed float2
        renderPipelineDescriptor.vertexDescriptor = builder.vertexDescriptor

        let fragmentFunction = mtlLibrary.makeFunction(name: "pixelBufferFragmentShader")
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        return renderPipelineDescriptor
    }

    open func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        guard let texture = texture else {
            return
        }

        var uniforms = PixelBufferUniforms()
        uniforms.transform = simd_float3x4.scale([1 / (Float(renderer.viewport.width) * 0.5), 1 / (Float(renderer.viewport.height) * 0.5), 1])
        commandEncoder.setVertexValue(&uniforms, index: Int(PixelBufferVertexShader_Uniforms))

        vertices.withUnsafeBytes { buffer in
            commandEncoder.setVertexBytes(buffer.baseAddress!, length: buffer.count, index: Int(PixelBufferVertexShader_Vertices))
        }

        commandEncoder.setFragmentTexture(texture, index: Int(PixelBufferFramgentShader_Texture))
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
    }
}

// MARK: -

open class PixelBufferSubrenderer: TextureSubrenderer {
    public var pixelBuffer: Array2D<RGBA>
    public var updatePixelBuffer: ((inout Array2D<RGBA>) -> Void)?

    public init(device: MTLDevice, quadSize: CGSize, gridSize: IntSize) throws {
        pixelBuffer = Array2D<RGBA>(size: gridSize)

        try super.init(device: device, quadSize: quadSize)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: gridSize.width, height: gridSize.height, mipmapped: false)
        texture = device.makeTexture(descriptor: textureDescriptor)!
    }

    override open func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        guard let texture = texture else {
            return
        }

        updatePixelBuffer?(&pixelBuffer)
        let size = pixelBuffer.size
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: size.width, height: size.height, depth: 1))
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixelBuffer.flatStorage, bytesPerRow: size.width * MemoryLayout<RGBA>.size)

        try super.encode(renderer: renderer, commandEncoder: commandEncoder)
    }
}
