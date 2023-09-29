import CoreGraphics
import Metal

public protocol RenderPass {
    associatedtype Configuration: RenderKitConfiguration

    mutating func setup(configuration: inout Configuration.Update) throws
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) throws // TODO: Rename and/or put into "ResizableRenderPass"
    func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer) throws
}

extension RenderPass {
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) {
    }
}
