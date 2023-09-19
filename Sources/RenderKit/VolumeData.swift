//
//  Scratch.swift
//  Demos
//
//  Created by Jonathan Wight on 9/17/23.
//

import Foundation
import Metal

public struct VolumeData {
    public var directoryURL: URL
    public var size: MTLSize
    
    public init(directoryURL: URL, size: MTLSize) {
        self.directoryURL = directoryURL
        self.size = size
    }
    
    public func load() throws -> (MTLDevice) throws -> MTLTexture {
        return { device in
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
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type3D
            textureDescriptor.pixelFormat = .r16Uint
            textureDescriptor.width = size.width
            textureDescriptor.height = size.height
            textureDescriptor.depth = size.depth
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                fatalError()
            }
            texture.label = directoryURL.lastPathComponent
            for slice in slices {
                let region = MTLRegionMake3D(0, 0, 0, size.width, size.height, 1)
                texture.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: slice, bytesPerRow: size.width * 2, bytesPerImage: size.width * size.height * 2)
            }
            
            return texture
        }
        
        

        
        
        
        
    }
}


//Description:    CT study of a cadaver head
//Dimensions:    113 slices of 256 x 256 pixels,
//        voxel grid is rectangular, and
//        X:Y:Z shape of each voxel is 1:1:2
//Files:        113 binary files, one file per slice
//File format:    16-bit integers (Mac byte ordering), file contains no header
//Data source:    acquired on a General Electric CT Scanner and provided
//                courtesy of North Carolina Memorial Hospital
