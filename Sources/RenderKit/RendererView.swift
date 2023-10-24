#if !os(visionOS)
import SwiftUI
import MetalSupport

public struct RendererView <T>: View where T: RenderPass, T.Configuration == MetalViewConfiguration {
    // TODO: Does this _really_ need to be a Binding?
    @Binding
    var renderPass: T

    @State
    var commandQueue: MTLCommandQueue?

    @Environment(\.metalDevice)
    var device

    public init(renderPass: Binding<T>) {
        self._renderPass = renderPass
    }

    public var body: some View {
        MetalView { device, configuration in
            configuration.preferredFramesPerSecond = 120
            configuration.colorPixelFormat = .bgra8Unorm_srgb
            configuration.depthStencilPixelFormat = .depth16Unorm
            configuration.depthStencilStorageMode = .memoryless
            try renderPass.setup(device: device, configuration: &configuration)
        } drawableSizeWillChange: { device, configuration, size in
            try renderPass.drawableSizeWillChange(device: device, configuration: &configuration, size: size)
        } draw: { device, configuration, size, currentDrawable, renderPassDescriptor in
            guard let commandQueue else {
                fatalError("Draw called before command queue set up. This should be impossible.")
            }
            try commandQueue.withCommandBuffer(drawable: currentDrawable, block: { commandBuffer in
                commandBuffer.label = "RendererView-CommandBuffer"
                try renderPass.draw(device: device, configuration: configuration, size: size, renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
            })
        }
        .onAppear {
            if commandQueue == nil {
                commandQueue = device.makeCommandQueue()
            }
        }
    }
}
#endif
