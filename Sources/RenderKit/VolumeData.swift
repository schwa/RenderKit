import Foundation
import Metal

//Description:    CT study of a cadaver head
//Dimensions:    113 slices of 256 x 256 pixels,
//        voxel grid is rectangular, and
//        X:Y:Z shape of each voxel is 1:1:2
//Files:        113 binary files, one file per slice
//File format:    16-bit integers (Mac byte ordering), file contains no header
//Data source:    acquired on a General Electric CT Scanner and provided
//                courtesy of North Carolina Memorial Hospital

public struct VolumeData {
    public var directoryURL: URL
    public var size: MTLSize
    
    public init(directoryURL: URL, size: MTLSize) {
        self.directoryURL = directoryURL
        self.size = size
    }
    
    public init(named name: String, size: MTLSize) {
        let url = Bundle.main.resourceURL!.appendingPathComponent("StanfordVolumeData/\(name)")
        self = .init(directoryURL: url, size: size)
    }
    
    func slices() throws -> [[UInt16]] {
        let slices = try FileManager().contentsOfDirectory(atPath: directoryURL.path)
            .map { directoryURL.appendingPathComponent($0) }
            .sorted { lhs, rhs in
                let lhs = Int(lhs.pathExtension)!
                let rhs = Int(rhs.pathExtension)!
                return lhs < rhs
            }
            .map {
                let data = try Data(contentsOf: $0)
                .withUnsafeBytes { buffer in
                    buffer.bindMemory(to: UInt16.self).map {
                        UInt16(bigEndian: $0)
                    }
                }
                // TODO: align data to device.minimumLinearTextureAlignment(for: .r16UInt)
                assert(data.count == size.width * size.height)
                return data
            }
        assert(slices.count == size.depth)
        return slices
    }
    
    func statistics() throws -> (histogram: [Int], min: UInt16, max: UInt16) {
        var counts = Array(repeating: 0, count: Int(UInt16.max))
        let slices = try slices()
        let values = slices.flatMap { $0 }
        values.forEach { value in
            counts[Int(value)] += 1
        }
        
        return (histogram: counts, min: values.min()!, max: values.max()!)
    }
    
    public func load() throws -> (MTLDevice) throws -> MTLTexture {
        return { device in
            let slices = try slices()
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type3D
            textureDescriptor.pixelFormat = .r16Uint
            textureDescriptor.storageMode = .shared
            
            textureDescriptor.width = size.width
            textureDescriptor.height = size.height
            textureDescriptor.depth = size.depth
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                fatalError()
            }
            texture.label = directoryURL.lastPathComponent
            let bytesPerRow = size.width * 2
            let bytesPerImage = size.width * size.height * 2
            for (index, slice) in slices.enumerated() {
                let region = MTLRegionMake3D(0, 0, index, size.width, size.height, 1)
                texture.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: slice, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage)
            }
            return device.makePrivateCopy(of: texture)
        }
    }
}

extension MTLDevice {
    /// "To copy your data to a private texture, copy your data to a temporary texture with non-private storage, and then use an MTLBlitCommandEncoder to copy the data to the private texture for GPU use."
    func makePrivateCopy(of source: MTLTexture) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = source.textureType
        textureDescriptor.pixelFormat = source.pixelFormat
        textureDescriptor.storageMode = .private
        
        textureDescriptor.width = source.width
        textureDescriptor.height = source.height
        textureDescriptor.depth = source.depth
        guard let destination = makeTexture(descriptor: textureDescriptor) else {
            fatalError()
        }
        destination.label = source.label.map { "\($0)-private-copy" }

        guard let commandQueue = makeCommandQueue() else {
            fatalError()
        }
        commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
            guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
                fatalError()
            }
            encoder.copy(from: source, to: destination)
            encoder.endEncoding()
        }
        return destination
    }
}
