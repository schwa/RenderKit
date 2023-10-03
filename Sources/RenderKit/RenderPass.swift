import CoreGraphics
import Metal

public protocol RenderPass: AnyObject {
    typealias Configuration = MetalConfiguration

    func setup(device: MTLDevice, configuration: inout Configuration) throws
    func drawableSizeWillChange(device: MTLDevice, configuration: inout Configuration, size: CGSize) throws
    func draw(device: MTLDevice, configuration: Configuration, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws
}
