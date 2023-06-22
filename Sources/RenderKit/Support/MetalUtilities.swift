import Everything
import Foundation
import Metal
import MetalKit
import ModelIO
import simd

public extension MTLTexture {
    // TODO: assumes texture data is in main memory not GPU memory
    func toCGImage() -> CGImage {
        switch pixelFormat {
        case .r8Uint, .r8Unorm:
            var pixelBuffer = Array2D<UInt8>(repeating: 0, size: IntSize(width, height))
            getBytes(&pixelBuffer.flatStorage, bytesPerRow: MemoryLayout<UInt8>.size * width, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return pixelBuffer.cgImage
        case .bgra8Unorm_srgb:
            typealias PixelType = RGBA
            var pixelBuffer = Array2D<RGBA>(size: IntSize(width, height))
            getBytes(&pixelBuffer.flatStorage, bytesPerRow: MemoryLayout<PixelType>.size * width, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return pixelBuffer.cgImage
        default:
            fatal(error: GeneralError.illegalValue)
        }
    }

    #if os(macOS)
        func toNSImage() -> NSImage {
            NSImage(cgImage: toCGImage(), size: CGSize(width: width, height: height))
        }

        func write(to url: URL) throws {
            assert(url.pathExtension == "tiff")
            try toNSImage().tiffRepresentation!.write(to: url)
        }
    #endif
}

public extension MDLMeshBufferAllocator {
    func newBuffer<Element>(with array: [Element], type: MDLMeshBufferType) -> MDLMeshBuffer {
        assert(_isPOD(Element.self))
        return array.withUnsafeBytes { buffer in
            let data = Data(buffer)
            return newBuffer(with: data, type: type)
        }
    }
}

extension MDLVertexFormat: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "invalid"
        case .packedBit: return "packedBit"
        case .uCharBits: return "uCharBits"
        case .charBits: return "charBits"
        case .uCharNormalizedBits: return "uCharNormalizedBits"
        case .charNormalizedBits: return "charNormalizedBits"
        case .uShortBits: return "uShortBits"
        case .shortBits: return "shortBits"
        case .uShortNormalizedBits: return "uShortNormalizedBits"
        case .shortNormalizedBits: return "shortNormalizedBits"
        case .uIntBits: return "uIntBits"
        case .intBits: return "intBits"
        case .halfBits: return "halfBits"
        case .floatBits: return "floatBits"
        case .uChar: return "uChar"
        case .uChar2: return "uChar2"
        case .uChar3: return "uChar3"
        case .uChar4: return "uChar4"
        case .char: return "char"
        case .char2: return "char2"
        case .char3: return "char3"
        case .char4: return "char4"
        case .uCharNormalized: return "uCharNormalized"
        case .uChar2Normalized: return "uChar2Normalized"
        case .uChar3Normalized: return "uChar3Normalized"
        case .uChar4Normalized: return "uChar4Normalized"
        case .charNormalized: return "charNormalized"
        case .char2Normalized: return "char2Normalized"
        case .char3Normalized: return "char3Normalized"
        case .char4Normalized: return "char4Normalized"
        case .uShort: return "uShort"
        case .uShort2: return "uShort2"
        case .uShort3: return "uShort3"
        case .uShort4: return "uShort4"
        case .short: return "short"
        case .short2: return "short2"
        case .short3: return "short3"
        case .short4: return "short4"
        case .uShortNormalized: return "uShortNormalized"
        case .uShort2Normalized: return "uShort2Normalized"
        case .uShort3Normalized: return "uShort3Normalized"
        case .uShort4Normalized: return "uShort4Normalized"
        case .shortNormalized: return "shortNormalized"
        case .short2Normalized: return "short2Normalized"
        case .short3Normalized: return "short3Normalized"
        case .short4Normalized: return "short4Normalized"
        case .uInt: return "uInt"
        case .uInt2: return "uInt2"
        case .uInt3: return "uInt3"
        case .uInt4: return "uInt4"
        case .int: return "int"
        case .int2: return "int2"
        case .int3: return "int3"
        case .int4: return "int4"
        case .half: return "half"
        case .half2: return "half2"
        case .half3: return "half3"
        case .half4: return "half4"
        case .float: return "float"
        case .float2: return "float2"
        case .float3: return "float3"
        case .float4: return "float4"
        case .int1010102Normalized: return "int1010102Normalized"
        case .uInt1010102Normalized: return "uInt1010102Normalized"
        @unknown default:
            fatalError()
        }
    }
}
