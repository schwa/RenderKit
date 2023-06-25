import Everything
import Metal
import SwiftUI
import RenderKitSupport

public struct RenderView<RenderGraph>: View where RenderGraph: RenderGraphProtocol {
    let device: MTLDevice

    @State
    var renderer: Renderer<RenderGraph>

    @State
    var drawableSize: CGSize = .zero

    public init(device: MTLDevice, renderer: Renderer<RenderGraph>) {
        self.device = device
        self.renderer = renderer
    }

    public var body: some View {
        MetalView(device: device, drawableSize: $drawableSize) { drawable in
            tryElseLog {
                try renderer.render(drawable: drawable)
            }
        }
        .onChange(of: drawableSize) {
            renderer.update(targetTextureSize: drawableSize)
        }
    }
}
