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
    func drawableSizeWillChange(device: MTLDevice, size: CGSize) throws
    func draw (device: MTLDevice, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws
}

public extension RenderPass {
    func drawableSizeWillChange(device: MTLDevice, size: CGSize) throws {
    }
}

// MARK: -

// TODO: Combine jobs and passes

public protocol RenderJob: AnyObject {
    func setup<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws
    func drawableSizeWillChange(device: MTLDevice, size: CGSize) throws
    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws // TODO: Add configuration just to be consistent? Or remove from renderpass.
}

public extension RenderJob {
    func drawableSizeWillChange(device: MTLDevice, size: CGSize) throws {
    }
}
