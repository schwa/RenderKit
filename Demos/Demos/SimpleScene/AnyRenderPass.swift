import Metal
import RenderKit

public final class AnyRenderPass <Configuration>: RenderPass where Configuration: MetalConfiguration {
    private var base: Any?
    private var _setup: (MTLDevice, inout Configuration) throws -> Void
    private var _drawableSizeWillChange: (MTLDevice, inout Configuration, CGSize) throws -> Void
    private var _draw: (MTLDevice, Configuration, CGSize, MTLRenderPassDescriptor, MTLCommandBuffer) throws -> Void

    public init(setup: @escaping (MTLDevice, inout Configuration) throws -> Void, drawableSizeWillChange: @escaping (MTLDevice, inout Configuration, CGSize) throws -> Void = { _, _, _ in }, draw: @escaping (MTLDevice, Configuration, CGSize, MTLRenderPassDescriptor, MTLCommandBuffer) throws -> Void) {
        self.base = nil
        self._setup = setup
        self._drawableSizeWillChange = drawableSizeWillChange
        self._draw = draw
    }

    public init <Base>(base: Base) where Base: RenderPass, Base.Configuration == Configuration {
        self.base = base
        self._setup = base.setup(device:configuration:)
        self._drawableSizeWillChange = base.drawableSizeWillChange(device:configuration:size:)
        self._draw = base.draw(device:configuration:size:renderPassDescriptor:commandBuffer:)
    }

    public func setup(device: MTLDevice, configuration: inout Configuration) throws {
        try _setup(device, &configuration)
    }

    public func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws {
        try _drawableSizeWillChange(device, &configuration, size)
    }

    public func draw(device: MTLDevice, configuration: Configuration, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws {
        try _draw(device, configuration, size, renderPassDescriptor, commandBuffer)
    }
}
