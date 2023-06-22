import Foundation
import Metal

public class MetalCompute {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    public private(set) var function: MTLFunction?
    public private(set) var pipelineState: MTLComputePipelineState?
    public private(set) var threadGroups: MTLSize?
    public private(set) var threadsPerThreadGroup: MTLSize?

    public init(device: MTLDevice, commandQueue: MTLCommandQueue) throws {
        self.device = device
        self.commandQueue = commandQueue
    }

    public convenience init(device: MTLDevice? = nil) throws {
        let device = device ?? MTLCreateSystemDefaultDevice()!
        let commandQueue = device.makeCommandQueue()!
        try self.init(device: device, commandQueue: commandQueue)
    }

    public func use(function: MTLFunction, workSize: MTLSize) throws {
        pipelineState = try device.makeComputePipelineState(function: function)
        let threadExecutionWidth = pipelineState!.threadExecutionWidth // 16

        // let maxThreadsPerThreadgroup = device.maxThreadsPerThreadgroup // 1024
        // threadsPerThreadGroup.volume < 256 & < maxThreadsPerThreadgroup

        // TOTAL HACK
        threadGroups = MTLSize(
            width: min(threadExecutionWidth * 4, workSize.width),
            height: min(threadExecutionWidth * 4, workSize.height),
            depth: min(threadExecutionWidth * 4, workSize.depth)
        )
        threadsPerThreadGroup = MTLSize(
            width: workSize.width / threadGroups!.width,
            height: workSize.height / threadGroups!.height,
            depth: workSize.depth / threadGroups!.depth
        )
    }

    public func compute<R>(block: (MTLCommandBuffer, MTLComputeCommandEncoder) throws -> R) throws -> R {
        // TODO: This needs to be broken into two nested blocks - commandBuffer / commandEncoder

        guard let pipelineState = pipelineState else {
            fatalError("pipelineState not set - did you set a function?")
        }

        return try commandQueue.withCommandBuffer { commandBuffer in
            let result: R = try commandBuffer.withComputeCommandEncoder { commandEncoder in
                commandEncoder.setComputePipelineState(pipelineState)
                let r = try block(commandBuffer, commandEncoder)
                guard let threadGroups = threadGroups, let threadsPerThreadGroup = threadsPerThreadGroup else {
                    fatalError("Could not get thread groups")
                }
                commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadGroup)
                return r
            }

            // TODO: Do work here (blitting)

            return result
        }
    }
}

public extension MTLCommandQueue {
    func withCommandBuffer<R>(_ block: (MTLCommandBuffer) throws -> R) rethrows -> R {
        let commandBuffer = makeCommandBuffer()!
        let r = try block(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted() // TODO:
        return r
    }
}

public extension MTLCommandBuffer {
    func withComputeCommandEncoder<R>(_ block: (MTLComputeCommandEncoder) throws -> R) rethrows -> R {
        let commandEncoder = makeComputeCommandEncoder()!
        let r = try block(commandEncoder)

        // commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadGroup)
        commandEncoder.endEncoding()
        return r
    }
}
