import SwiftUI
import MetalKit
import Everything
import os

public struct MetalView: View {
    @Observable
    class Model: NSObject, MTKViewDelegate {
        @ObservationIgnored
        var update: (inout ConcreteMetalViewConfiguration) -> Void = { _ in fatalError() }
        @ObservationIgnored
        var drawableSizeWillChange: (inout ConcreteMetalViewConfiguration, CGSize) -> Void = { _, _ in fatalError() }
        @ObservationIgnored
        var draw: (ConcreteMetalViewConfiguration) -> Void = { _ in fatalError() }
        @ObservationIgnored
        var lock = OSAllocatedUnfairLock()

        @ObservationIgnored
//        let queue: DispatchQueue? = DispatchQueue(label: "MetalView", qos: .userInteractive)
        let queue: DispatchQueue? = nil

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            drawableSizeWillChange(&view.concreteMetalViewConfiguration, size)
        }

        func draw(in view: MTKView) {
            if let queue {
                let configuration = view.concreteMetalViewConfiguration
                queue.async { [weak self] in
                    assert(!Thread.isMainThread)
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.lock.withLockIfAvailable {
                        strongSelf.draw(configuration)
                    }
                }
            }
            else {
                draw(view.concreteMetalViewConfiguration)
            }
        }
    }

    @State
    private var model = Model()

    var update: (inout ConcreteMetalViewConfiguration) -> Void
    var drawableSizeWillChange: (inout ConcreteMetalViewConfiguration, CGSize) -> Void
    var draw: (ConcreteMetalViewConfiguration) -> Void

    public init(update: @escaping (inout ConcreteMetalViewConfiguration) -> Void, drawableSizeWillChange: @escaping (inout ConcreteMetalViewConfiguration, CGSize) -> Void, draw: @escaping (ConcreteMetalViewConfiguration) -> Void) {
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
            Task {
                var configuration = view.concreteMetalViewConfiguration
                model.update(&configuration)
                view.concreteMetalViewConfiguration = configuration
            }
            return view
        } update: { view in
            //Self._printChanges()
            // Perform updates in a Task to allow clients to update state and avoid "Modifying state during view update, this will cause undefined behavior."
        }
        .onAppear {
            model.update = update
            model.drawableSizeWillChange = drawableSizeWillChange
            model.draw = draw
        }
    }
}

extension MetalView {
    public init(update: @escaping (inout ConcreteMetalViewConfiguration) -> Void, draw: @escaping (ConcreteMetalViewConfiguration) -> Void) {
        self.init(update: update, drawableSizeWillChange: { _, _ in }, draw: draw)
    }
}

// MARK: -

public protocol RenderKitConfiguration {
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

public protocol MetalViewUpdateConfiguration: RenderKitUpdateConfiguration {
    var currentDrawable: CAMetalDrawable? { get }
}

public protocol MetalViewDrawConfiguration: RenderKitDrawConfiguration {
    var currentDrawable: CAMetalDrawable? { get }
}

public struct MetalViewConfiguration: RenderKitConfiguration {
    public typealias Update = ConcreteMetalViewConfiguration

    public typealias Draw = ConcreteMetalViewConfiguration
}

public struct ConcreteMetalViewConfiguration: MetalViewUpdateConfiguration, MetalViewDrawConfiguration {
    public var currentDrawable: CAMetalDrawable?
    public var colorPixelFormat: MTLPixelFormat = .invalid
    public var depthStencilPixelFormat: MTLPixelFormat = .invalid
    public var depthStencilStorageMode: MTLStorageMode = .shared
    public var clearDepth: Double = 1
    public var preferredFramesPerSecond: Int = 120
    public var device: MTLDevice?
    public var size: CGSize?
    public var currentRenderPassDescriptor: MTLRenderPassDescriptor?
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

extension MTKView {

    var concreteMetalViewConfiguration: ConcreteMetalViewConfiguration {
        get {
            var configuration = ConcreteMetalViewConfiguration()
            configuration.currentDrawable = currentDrawable
            configuration.colorPixelFormat = colorPixelFormat
            configuration.depthStencilPixelFormat = depthStencilPixelFormat
            configuration.depthStencilStorageMode = depthStencilStorageMode
            configuration.clearDepth = clearDepth
            configuration.preferredFramesPerSecond = preferredFramesPerSecond
            configuration.device = device
            configuration.size = bounds.size
            configuration.currentRenderPassDescriptor = currentRenderPassDescriptor
            return configuration
        }
        set {
            colorPixelFormat = newValue.colorPixelFormat
            depthStencilPixelFormat = newValue.depthStencilPixelFormat
            depthStencilStorageMode = newValue.depthStencilStorageMode
            clearDepth = newValue.clearDepth
            preferredFramesPerSecond = newValue.preferredFramesPerSecond
            device = newValue.device
        }
    }
}
