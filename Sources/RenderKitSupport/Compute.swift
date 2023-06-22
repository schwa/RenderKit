import CoreGraphics
import Everything
import Foundation
import Metal
import SwiftUI

public struct Compute {
    public var function: MTLFunction

    public init(function: MTLFunction) {
        self.function = function
    }

    public static func compute<R>(function: MTLFunction, _ encode: (MTLComputeCommandEncoder, inout ComputeWorkSize) throws -> R) throws -> R {
        let device = function.device
        let commandQueue = device.makeCommandQueue()!
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let compute = Compute(function: function)
        let result = try compute.compute(commandBuffer: commandBuffer, encode)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return result
    }

    public func compute<R>(commandBuffer: MTLCommandBuffer, _ encode: (MTLComputeCommandEncoder, inout ComputeWorkSize) throws -> R) throws -> R {
        let device = commandBuffer.device
        let pipelineState = try device.makeComputePipelineState(function: function)
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        defer {
            commandEncoder.endEncoding()
        }
        commandEncoder.setComputePipelineState(pipelineState)
        var workSize = ComputeWorkSize(pipelineState: pipelineState)
        let result = try encode(commandEncoder, &workSize)
        guard let threadsPerGrid = workSize.threadsPerGrid, let threadsPerThreadGroup = workSize.threadsPerThreadGroup else {
            fatalError("Could not get work size data")
        }
        if device.supportsNonuniformThreadGroupSizes {
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        }
        else {
            // TODO: Hack
            commandEncoder.dispatchThreadgroups([1, 1, 1], threadsPerThreadgroup: threadsPerThreadGroup)
        }
        return result
    }
}

// extension PixelFormat {
//
//    enum CGContextHappyRGB {
//        case a
//    }
//
//    Valid parameters for RGB color space model are:
//        16  bits per pixel,         5  bits per component,         kCGImageAlphaNoneSkipFirst
//        32  bits per pixel,         8  bits per component,         kCGImageAlphaNoneSkipFirst
//        32  bits per pixel,         8  bits per component,         kCGImageAlphaNoneSkipLast
//        32  bits per pixel,         8  bits per component,         kCGImageAlphaPremultipliedFirst
//        32  bits per pixel,         8  bits per component,         kCGImageAlphaPremultipliedLast
//        32  bits per pixel,         10 bits per component,         kCGImageAlphaNone|kCGImagePixelFormatRGBCIF10
//        64  bits per pixel,         16 bits per component,         kCGImageAlphaPremultipliedLast
//        64  bits per pixel,         16 bits per component,         kCGImageAlphaNoneSkipLast
//        64  bits per pixel,         16 bits per component,         kCGImageAlphaPremultipliedLast|kCGBitmapFloatComponents|kCGImageByteOrder16Little
//        64  bits per pixel,         16 bits per component,         kCGImageAlphaNoneSkipLast|kCGBitmapFloatComponents|kCGImageByteOrder16Little
//        128 bits per pixel,         32 bits per component,         kCGImageAlphaPremultipliedLast|kCGBitmapFloatComponents
//        128 bits per pixel,         32 bits per component,         kCGImageAlphaNoneSkipLast|kCGBitmapFloatComponents
//        See Quartz 2D Programming Guide (available online) for more information.
// }
