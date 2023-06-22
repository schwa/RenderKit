import Combine
import Everything
import Metal
import SwiftUI
import Observation

// https://developer.apple.com/documentation/corevideo/cvtime-q1e

public struct MetalView: View {
    let device: MTLDevice

    @Binding
    var drawableSize: CGSize

    let draw: (CAMetalDrawable) -> Void

    let drawID: AnyHashable

    var coordinator = Coordinator()

    @Environment(\.timingStatisticsPublisher)
    var timingStatisticsPublisher

    @Environment(\.displayLink)
    var displayLink

    public init(device: MTLDevice, drawableSize: Binding<CGSize> = .constant(.zero), drawID: AnyHashable, draw: @escaping (CAMetalDrawable) -> Void) {
        self.device = device
        _drawableSize = drawableSize
        self.drawID = drawID
        self.draw = draw
    }

    public var body: some View {
        ViewAdaptor {
            let view = MetalPlatformView(frame: CGRect(width: 240, height: 160))
            #if os(macOS)
                view.wantsLayer = true
            #endif
            view.didUpdate = { size in
                Task {
                    self.drawableSize = size
                }
            }

            guard let metalLayer = view.layer as? CAMetalLayer else {
                fatalError("No CAMetalLayer on view.")
            }
            metalLayer.device = device
            metalLayer.framebufferOnly = true

            #if os(macOS)
                metalLayer.wantsExtendedDynamicRangeContent = true
                metalLayer.pixelFormat = .bgra10_xr_srgb
                metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedSRGB)
            #elseif os(iOS)
                metalLayer.pixelFormat = .bgra8Unorm_srgb
                metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
            #endif
            coordinator.metalLayer = metalLayer
            return view
        } update: { _ in
        }
        .task {
            let displayLinkSequence = AsyncPublisher(displayLink)
            for await _ in displayLinkSequence {
                coordinator.tick(draw: draw)
            }
        }
    }

    class Coordinator {
        var device: MTLDevice? {
            metalLayer?.device
        }

        var metalLayer: CAMetalLayer?

        func tick(draw: ((CAMetalDrawable) -> Void)) {
            //                    let s = event.duration?.seconds ?? 1.0
            // https://developer.apple.com/documentation/corevideo/cvtime-q1e
            guard let metalLayer else {
                return
            }
            guard let drawable = metalLayer.nextDrawable() else {
                warning("No drawable")
                return
            }

            RenderLoopTracker.shared.withRenderLoop {
                draw(drawable)
            }
        }
    }
}

#if os(macOS)
    internal class MetalPlatformView: NSView {
        var didUpdate: ((CGSize) -> Void)?

        var metalLayer: CAMetalLayer {
            // swiftlint:disable:next force_cast
            layer as! CAMetalLayer
        }

        override func makeBackingLayer() -> CALayer {
            CAMetalLayer()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)

            let desiredDrawableSize = metalLayer.frame.size * metalLayer.contentsScale
            if metalLayer.drawableSize != desiredDrawableSize {
                metalLayer.drawableSize = desiredDrawableSize
                didUpdate?(metalLayer.drawableSize)
            }
        }

        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            metalLayer.contentsScale = window!.backingScaleFactor
            metalLayer.drawableSize = metalLayer.frame.size * metalLayer.contentsScale
            didUpdate?(metalLayer.drawableSize)
        }
    }
#endif

// MARK: -

#if os(iOS)
    internal class MetalPlatformView: UIView {
        var didUpdate: ((CGSize) -> Void)?

        override class var layerClass: AnyClass {
            CAMetalLayer.self
        }

        override var frame: CGRect {
            didSet {
                didUpdate?(frame.size * 2)
            }
        }

        var metalLayer: CAMetalLayer {
            // swiftlint:disable:next force_cast
            layer as! CAMetalLayer
        }
    }
#endif

extension CGSize {
    var isEmpty: Bool {
        height > 0 && width > 0
    }
}
