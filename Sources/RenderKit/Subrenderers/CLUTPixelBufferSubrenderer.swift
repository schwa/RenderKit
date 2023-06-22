import CoreGraphics
import Everything
import Metal
import RenderKitShaders
import simd
import SIMDSupport

open class CLUTPixelBufferSubrenderer: Subrenderer {
    public let size: IntSize
    public let colors: [CGColor]
    let vertices: [VertexBasicX]
    public var lookupTexture: MTLTexture!
    public let colorMapTexture: MTLTexture!

    public init(device: MTLDevice, quadSize: CGSize, gridSize: IntSize, colors: [CGColor]) throws {
        size = gridSize
        self.colors = colors

        let (w, h) = (Float(quadSize.width) * 0.5, Float(quadSize.height) * 0.5)
        vertices = [
            VertexBasicX(position: [-w, -h], textureCoords: [0, 1]),
            VertexBasicX(position: [w, -h], textureCoords: [1, 1]),
            VertexBasicX(position: [-w, h], textureCoords: [0, 0]),
            VertexBasicX(position: [w, h], textureCoords: [1, 0]),
        ]

        // LOOK UP TEXTURE
        let lookupTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint, width: gridSize.width, height: gridSize.height, mipmapped: false)
        lookupTexture = device.makeTexture(descriptor: lookupTextureDescriptor)!

        // COLOR MAP
        colorMapTexture = CLUTPixelBufferSubrenderer.makeColorMapTexture(device: device, colors: colors)
    }

    open func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let mtlLibrary = try renderer.device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let vertexFunction = mtlLibrary.makeFunction(name: "clutPixelBufferVertexShader")
        renderPipelineDescriptor.vertexFunction = vertexFunction

        var builder = VertexDescriptorBuilder()
        builder.addAttribute(format: .float2, size: 8) // size of packed float2
        builder.addAttribute(format: .float2, size: 8) // size of packed float2
        renderPipelineDescriptor.vertexDescriptor = builder.vertexDescriptor

        let fragmentFunction = mtlLibrary.makeFunction(name: "clutPixelBufferFragmentShader")
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        return renderPipelineDescriptor
    }

    open func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        var uniforms = PixelBufferUniforms()
        uniforms.transform = simd_float3x4.scale([1 / (Float(renderer.viewport.width) * 0.5), 1 / (Float(renderer.viewport.height) * 0.5), 1])
        commandEncoder.setVertexValue(&uniforms, index: Int(PixelBufferVertexShader_Uniforms))

        vertices.withUnsafeBytes { buffer in
            commandEncoder.setVertexBytes(buffer.baseAddress!, length: buffer.count, index: Int(CLUTPixelBufferVertexShader_Vertices))
        }

        commandEncoder.setFragmentTexture(lookupTexture, index: Int(CLUTPixelBufferFragmentShader_LookupTexture))
        commandEncoder.setFragmentTexture(colorMapTexture, index: Int(CLUTPixelBufferFragmentShader_ColorMapTexture))

        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
    }

    static func makeColorMapTexture(device: MTLDevice, colors: [CGColor]) -> MTLTexture {
        let colorMapTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: colors.count, height: 1, mipmapped: false)
        guard let colorMapTexture = device.makeTexture(descriptor: colorMapTextureDescriptor) else {
            fatal(error: GeneralError.unhandledSystemFailure)
        }

        let rgbas = colors.map { color -> RGBA in
            RGBA(cgColor: color)
        }
        colorMapTexture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: colors.count, height: 1, depth: 1)), mipmapLevel: 0, withBytes: rgbas, bytesPerRow: colors.count * MemoryLayout<RGBA>.size)

        return colorMapTexture
    }
}
