import CoreGraphics
import Metal

public protocol MetalConfiguration {
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var depthStencilStorageMode: MTLStorageMode { get set }
    var clearDepth: Double { get set }
}

public struct MetalViewConfiguration: MetalConfiguration {
    // TODO: Fully expand this.
    public var colorPixelFormat: MTLPixelFormat
    public var depthStencilPixelFormat: MTLPixelFormat
    public var depthStencilStorageMode: MTLStorageMode
    public var clearDepth: Double
    public var preferredFramesPerSecond: Int
}

// MARK: -

public protocol RenderPass: AnyObject {
    func setup <Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws
    func drawableSizeWillChange <Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws
    func draw <Configuration: MetalConfiguration>(device: MTLDevice, configuration: Configuration, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws
}

// MARK: -

// TODO: Combine jobs and passes

public protocol SimpleRenderJob: AnyObject {
    func prepare<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws
    func drawableSizeWillChange<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws
    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws // TODO: Add configuration just to be consistent? Or remove from renderpass.
}

public extension SimpleRenderJob {
    func drawableSizeWillChange<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws {
    }
}
