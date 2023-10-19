import RenderKit
import Metal

public class SimpleJobsBasedRenderPass <Configuration>: RenderPass where Configuration: MetalConfiguration {
    public var jobs: [AnyRenderJob<Configuration>]

    public init(jobs: [AnyRenderJob<Configuration>]) {
        self.jobs = jobs
    }

    public func setup(device: MTLDevice, configuration: inout Configuration) throws {
        try jobs.forEach { job in
            try job.prepare(device: device, configuration: &configuration)
        }
    }

    public func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws {
        try jobs.forEach { job in
            try job.drawableSizeWillChange(device: device, configuration: &configuration, size: size)
        }
    }

    public func draw(device: MTLDevice, configuration: Configuration, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws {
        try commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
            try jobs.forEach { job in
                try job.encode(on: encoder, size: size)
            }
        }
    }
}

extension SimpleJobsBasedRenderPass: Observable {
}

// MARK: -

public protocol SimpleRenderJob: AnyObject {
    associatedtype Configuration: MetalConfiguration
    func prepare(device: MTLDevice, configuration: inout Configuration) throws
    func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws
    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws
}

public extension SimpleRenderJob {
    func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws {
    }
}

// MARK: -

public class AnyRenderJob <Configuration>: SimpleRenderJob where Configuration: MetalConfiguration {
    var base: Any
    var _prepare: (MTLDevice, inout Configuration) throws -> Void
    var _drawableSizeWillChange: (MTLDevice, inout Configuration, CGSize) throws -> Void
    var _encode: (MTLRenderCommandEncoder, CGSize) throws -> Void

    public init<Base>(_ base: Base) where Base: SimpleRenderJob, Base.Configuration == Configuration {
        self.base = base
        _prepare = base.prepare(device:configuration:)
        _drawableSizeWillChange = base.drawableSizeWillChange(device:configuration:size:)
        _encode = base.encode(on:size:)
    }

    public func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws {
        try _drawableSizeWillChange(device, &configuration, size)
    }

    public func prepare(device: MTLDevice, configuration: inout Configuration) throws {
        try _prepare(device, &configuration)
    }

    public func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        try _encode(encoder, size)
    }
}
