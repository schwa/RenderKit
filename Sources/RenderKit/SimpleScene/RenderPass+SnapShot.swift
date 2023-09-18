import Metal
import CoreGraphics

extension RenderPass {
    mutating func snapshot(device: MTLDevice) async throws -> CGImage {
        fatalError("Unimplemented")
        // TODO: RenderPasses are now bound to Render Configurations now. We can't just re-render. Need to recreate the render pass with new configuration?
//        var configuration = OffscreenRenderPassConfiguration()
//        configuration.colorPixelFormat = .bgra8Unorm_srgb
//        configuration.depthStencilPixelFormat = .depth16Unorm
//        configuration.device = device
//        configuration.update()
//        setup(configuration: configuration)
//        guard let commandQueue = device.makeCommandQueue() else {
//            fatalError()
//        }
//        commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
//            self.draw(configuration: configuration, commandBuffer: commandBuffer)
//        }
//        let cgImage = await configuration.targetTexture!.cgImage(colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB))
//        return cgImage
    }
}
