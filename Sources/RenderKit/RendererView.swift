import SwiftUI

public struct RendererView <T>: View where T: RenderPass, T.DrawConfiguration == ConcreteMetalViewConfiguration, T.UpdateConfiguration == ConcreteMetalViewConfiguration {
    @Binding
    var renderPass: T

    @State
    var commandQueue: MTLCommandQueue?

    public var body: some View {
        MetalView { configuration in
            configuration.preferredFramesPerSecond = 120
            configuration.colorPixelFormat = .bgra8Unorm
            configuration.depthStencilPixelFormat = .depth16Unorm
            configuration.depthStencilStorageMode = .memoryless

            renderPass.setup(configuration: &configuration)
            commandQueue = configuration.device!.makeCommandQueue()
        }
        draw: { configuration in
            commandQueue?.withCommandBuffer(drawable: configuration.currentDrawable, block: { commandBuffer in
                renderPass.draw(configuration: configuration, commandBuffer: commandBuffer)
            })
        }
    }
}

