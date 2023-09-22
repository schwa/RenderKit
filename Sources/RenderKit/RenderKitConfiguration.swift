import Metal
import QuartzCore

// TODO: Rename to RendererConfiguration
public protocol RenderKitConfiguration {
    // TODO: It's silly that this has to be broken in two.
    associatedtype Update: RenderKitUpdateConfiguration
    associatedtype Draw: RenderKitDrawConfiguration
}

public protocol RenderKitUpdateConfiguration {
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var depthStencilStorageMode: MTLStorageMode { get set }
    var clearDepth: Double { get set }
    var preferredFramesPerSecond: Int { get set }

    var device: MTLDevice? { get set }
    var size: CGSize? { get set }
}

public protocol RenderKitDrawConfiguration {
    var colorPixelFormat: MTLPixelFormat { get }
    var depthStencilPixelFormat: MTLPixelFormat { get }
    var depthStencilStorageMode: MTLStorageMode { get }
    var clearDepth: Double { get }
    var preferredFramesPerSecond: Int { get }

    var device: MTLDevice? { get }
    var size: CGSize? { get }

    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
}

//public protocol RenderPassConfiguration {
//    var device: MTLDevice? { get set }
//    //    var currentDrawable: CAMetalDrawable? { get }
//    //    var framebufferOnly: Bool { get set }
//    var depthStencilAttachmentTextureUsage: MTLTextureUsage { get set }
//    //    var multisampleColorAttachmentTextureUsage: MTLTextureUsage { get set }
//    //    var presentsWithTransaction: Bool { get set }
//    var colorPixelFormat: MTLPixelFormat { get set }
//    var depthStencilPixelFormat: MTLPixelFormat { get set }
//    var depthStencilStorageMode: MTLStorageMode { get set }
//    //    var sampleCount: Int { get set }
//    var clearColor: MTLClearColor { get set }
//    var clearDepth: Double { get set }
//    //    var clearStencil: UInt32 { get set }
//    var depthStencilTexture: MTLTexture? { get }
//    //    var multisampleColorTexture: MTLTexture? { get }
//    //    func releaseDrawables()
//    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
//    //    var preferredFramesPerSecond: Int { get set }
//    //    var enableSetNeedsDisplay: Bool { get set }
//    //    var autoResizeDrawable: Bool { get set }
//    //    var drawableSize: CGSize { get set }
//    //    var preferredDrawableSize: CGSize { get }
//    //    var preferredDevice: MTLDevice? { get }
//    //    var isPaused: Bool { get set }
//    //    var colorspace: CGColorSpace? { get set }
//
//    var size: CGSize? { get } // TODO: Rename, make optional?
//}
