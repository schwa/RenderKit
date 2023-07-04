import SwiftUI

public struct RendererView <T>: View where T: RenderPass {
    @Binding
    var renderPass: T

    @State
    var commandQueue: MTLCommandQueue?

    public var body: some View {
        MetalView { configuration in
            configuration.preferredFramesPerSecond = 120
            configuration.colorPixelFormat = .bgra8Unorm_srgb
            configuration.depthStencilPixelFormat = .depth16Unorm
            configuration.depthStencilStorageMode = .memoryless
            renderPass.setup(configuration: configuration)
            commandQueue = configuration.device!.makeCommandQueue()
        }
        draw: { configuration in
            commandQueue?.withCommandBuffer(drawable: configuration.currentDrawable, block: { commandBuffer in
                renderPass.draw(configuration: configuration, commandBuffer: commandBuffer)
            })
        }
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

