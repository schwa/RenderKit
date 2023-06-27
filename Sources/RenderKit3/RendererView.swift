import SwiftUI

public struct RendererView <T>: View where T: RenderPass {
    @Binding
    var renderPass: T

    @State
    var commandQueue: MTLCommandQueue?

    public var body: some View {
        MetalView2 { configuration in
            Task {
                configuration.preferredFramesPerSecond = 120
                configuration.colorPixelFormat = .bgra10_xr_srgb
                configuration.depthStencilPixelFormat = .depth16Unorm
                configuration.depthStencilStorageMode = .memoryless
                renderPass.setup(configuration: configuration)
                commandQueue = configuration.device!.makeCommandQueue()
            }
        }
        draw: { configuration in
        commandQueue?.withCommandBuffer(drawable: configuration.currentDrawable, block: { commandBuffer in
            renderPass.draw(configuration: configuration, commandBuffer: commandBuffer)
        })
    }
    }
}
