import SwiftUI
import MetalKit
import Everything

public struct MetalView2: View {
    @Observable
    class Model: NSObject, MTKViewDelegate {

        let setup: (inout any MetalViewConfiguration) -> Void
        let drawableSizeWillChange: (CGSize) -> Void
        let draw: (inout any MetalViewConfiguration) -> Void

        init(setup: @escaping (inout any MetalViewConfiguration) -> Void, drawableSizeWillChange: @escaping (CGSize) -> Void, draw: @escaping (inout any MetalViewConfiguration) -> Void) {
            print("Model.init")
            self.setup = setup
            self.drawableSizeWillChange = drawableSizeWillChange
            self.draw = draw
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            drawableSizeWillChange(size)
        }

        func draw(in view: MTKView) {
            var configuration = view as any MetalViewConfiguration
            draw(&configuration)
        }
    }

    private var model: Model

    public init(setup: @escaping (inout any MetalViewConfiguration) -> Void, drawableSizeWillChange: @escaping (CGSize) -> Void, draw: @escaping (inout any MetalViewConfiguration) -> Void) {
        print(#function)
        model = Model(setup: setup, drawableSizeWillChange: drawableSizeWillChange, draw: draw)
    }

    public var body: some View {
        ViewAdaptor<MTKView> {
            let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice()!)
            view.delegate = model
            var configuration = view as any MetalViewConfiguration
            model.setup(&configuration)
            return view
        } update: { view in
            print("Update")
        }
    }
}

// TODO: this needs to be paired down and replaced with better logic on MetalView
public protocol MetalViewConfiguration {
    var device: MTLDevice? { get set }
    var currentDrawable: CAMetalDrawable? { get }
    var framebufferOnly: Bool { get set }
    var depthStencilAttachmentTextureUsage: MTLTextureUsage { get set }
    var multisampleColorAttachmentTextureUsage: MTLTextureUsage { get set }
    var presentsWithTransaction: Bool { get set }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var depthStencilStorageMode: MTLStorageMode { get set }
    var sampleCount: Int { get set }
    var clearColor: MTLClearColor { get set }
    var clearDepth: Double { get set }
    var clearStencil: UInt32 { get set }
    var depthStencilTexture: MTLTexture? { get }
    var multisampleColorTexture: MTLTexture? { get }
    func releaseDrawables()
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var preferredFramesPerSecond: Int { get set }
    var enableSetNeedsDisplay: Bool { get set }
    var autoResizeDrawable: Bool { get set }
    var drawableSize: CGSize { get set }
    var preferredDrawableSize: CGSize { get }
    var preferredDevice: MTLDevice? { get }
    var isPaused: Bool { get set }
    var colorspace: CGColorSpace? { get set }
}

extension MTKView: MetalViewConfiguration {
}
