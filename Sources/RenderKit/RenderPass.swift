import CoreGraphics
import Metal

public protocol RenderPass {
    associatedtype Configuration: RenderKitConfiguration

    mutating func setup(configuration: inout Configuration.Update)
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) // TODO: Rename and/or put into "ResizableRenderPass"
    func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer)
}

extension RenderPass {
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) {
    }
}
