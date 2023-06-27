import SwiftUI
import MetalKit
import Everything
import os

let logger = os.Logger()

public struct MetalView2: View {
    @Observable
    class Model: NSObject, MTKViewDelegate {
        var update: (any MetalViewConfiguration) -> Void = { _ in fatalError() }
        var drawableSizeWillChange: (CGSize) -> Void = { _ in fatalError() }
        var draw: (any MetalViewConfiguration) -> Void = { _ in fatalError() }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//            logger.debug("\(String(describing: type(of: self)), privacy: .public).\(#function, privacy: .public)")
            drawableSizeWillChange(size)
        }

        func draw(in view: MTKView) {
//            logger.debug("\(String(describing: type(of: self)), privacy: .public).\(#function, privacy: .public)")
            draw(view as any MetalViewConfiguration)
        }
    }

    @State
    private var model = Model()

    var update: (any MetalViewConfiguration) -> Void
    var drawableSizeWillChange: (CGSize) -> Void
    var draw: (any MetalViewConfiguration) -> Void

    public init(update: @escaping (any MetalViewConfiguration) -> Void, drawableSizeWillChange: @escaping (CGSize) -> Void, draw: @escaping (any MetalViewConfiguration) -> Void) {
        self.update = update
        self.drawableSizeWillChange = drawableSizeWillChange
        self.draw = draw
    }

    @Environment(\.metalDevice)
    var device

    public var body: some View {
        ViewAdaptor<MTKView> {
            model.update = update
            model.drawableSizeWillChange = drawableSizeWillChange
            model.draw = draw

//            logger.debug("\(String(describing: type(of: self)), privacy: .public).\(#function, privacy: .public), view adaptor setup")
            let view = MTKView(frame: .zero, device: device)
            view.delegate = model
            return view
        } update: { view in
            model.update(view as any MetalViewConfiguration)
        }
        .onAppear {
            model.update = update
            model.drawableSizeWillChange = drawableSizeWillChange
            model.draw = draw
        }
    }
}

extension MetalView2 {
    public init(update: @escaping (any MetalViewConfiguration) -> Void, draw: @escaping (any MetalViewConfiguration) -> Void) {
        self.init(update: update, drawableSizeWillChange: { _ in }, draw: draw)
    }
}

public protocol RenderPassConfiguration {
    var device: MTLDevice? { get set }
//    var currentDrawable: CAMetalDrawable? { get }
//    var framebufferOnly: Bool { get set }
    var depthStencilAttachmentTextureUsage: MTLTextureUsage { get set }
//    var multisampleColorAttachmentTextureUsage: MTLTextureUsage { get set }
//    var presentsWithTransaction: Bool { get set }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var depthStencilStorageMode: MTLStorageMode { get set }
//    var sampleCount: Int { get set }
    var clearColor: MTLClearColor { get set }
    var clearDepth: Double { get set }
//    var clearStencil: UInt32 { get set }
    var depthStencilTexture: MTLTexture? { get }
//    var multisampleColorTexture: MTLTexture? { get }
//    func releaseDrawables()
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
//    var preferredFramesPerSecond: Int { get set }
//    var enableSetNeedsDisplay: Bool { get set }
//    var autoResizeDrawable: Bool { get set }
//    var drawableSize: CGSize { get set }
//    var preferredDrawableSize: CGSize { get }
//    var preferredDevice: MTLDevice? { get }
//    var isPaused: Bool { get set }
//    var colorspace: CGColorSpace? { get set }

    var size: CGSize? { get } // TODO: Rename, make optional?
}

// TODO: this needs to be paired down and replaced with better logic on MetalView
public protocol MetalViewConfiguration: AnyObject, RenderPassConfiguration {
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
    public var size: CGSize? {
        return currentDrawable?.layer.drawableSize
    }
    
}
