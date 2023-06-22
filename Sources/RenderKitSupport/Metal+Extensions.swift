// swiftlint:disable file_length

import Everything
@preconcurrency import Metal
import MetalSupport
import ModelIO
import os.log

private let yoloDevice = OSAllocatedUnfairLock<MTLDevice?>(initialState: nil)

public func MTLCreateYoloDevice(function: String = #function, line: Int = #line, file: String = #file, _ label: String? = nil) -> MTLDevice {
    yoloDevice.withLock { device in
        if device == nil {
            device = MTLCreateSystemDefaultDevice()!
        }
        else {
            os_log(.fault, "MTLCreateYoloDevice: \(file):\(line) --\(function) \(label ?? "")")
        }
        return device!
    }
}

// MARK: -

public struct ComputeWorkSize {
    public let maxTotalThreadsPerThreadgroup: Int
    public let threadExecutionWidth: Int

    public private(set) var threadsPerGrid: MTLSize?
    public private(set) var threadsPerThreadGroup: MTLSize?

    public init(pipelineState: MTLComputePipelineState) {
        maxTotalThreadsPerThreadgroup = pipelineState.maxTotalThreadsPerThreadgroup
        threadExecutionWidth = pipelineState.threadExecutionWidth
    }

    public mutating func configure(workSize: MTLSize) {
        // https://developer.apple.com/documentation/metal/creating_threads_and_threadgroups
        // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes

        switch (workSize.width, workSize.height, workSize.depth) {
        case (_, 1, 1):
            threadsPerThreadGroup = [threadExecutionWidth, 1, 1]
        case (_, _, 1):
            threadsPerThreadGroup = [threadExecutionWidth, maxTotalThreadsPerThreadgroup / threadExecutionWidth, 1]
        default:
            // NOTE: this broken
            threadsPerThreadGroup = [threadExecutionWidth, maxTotalThreadsPerThreadgroup / threadExecutionWidth, 1]
        }

        assert(workSize.width >= 1)
        assert(workSize.height >= 1)
//        assert(workSize.depth == 1)

        threadsPerGrid = workSize
    }

    public mutating func configure(threadsPerGrid: MTLSize, threadsPerThreadGroup: MTLSize) {
        self.threadsPerGrid = threadsPerGrid
        self.threadsPerThreadGroup = threadsPerThreadGroup
    }
}

