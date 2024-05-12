#if !os(visionOS)
import SwiftUI
import MetalKit
import Observation
import Everything

public struct MetalViewConfiguration: MetalConfiguration {
    // TODO: Fully expand this.
    public var colorPixelFormat: MTLPixelFormat
    public var clearColor: MTLClearColor
    public var depthStencilPixelFormat: MTLPixelFormat
    public var depthStencilStorageMode: MTLStorageMode
    public var clearDepth: Double
    public var preferredFramesPerSecond: Int
    public var enableSetNeedsDisplay: Bool
}

public struct MetalView: View {
    public typealias Setup = (MTLDevice, inout MetalViewConfiguration) throws -> Void
    public typealias DrawableSizeWillChange = (MTLDevice, inout MetalViewConfiguration, CGSize) throws -> Void
    public typealias Draw = (MTLDevice, MetalViewConfiguration, CGSize, CAMetalDrawable, MTLRenderPassDescriptor) throws -> Void

    @Environment(\.metalDevice)
    var device

    @State
    var model = MetalViewModel()

    @State
    var issetup = false

    @State
    var error: Error?

    let setup: MetalView.Setup
    let drawableSizeWillChange: MetalView.DrawableSizeWillChange
    let draw: MetalView.Draw

    public init(setup: @escaping Setup, drawableSizeWillChange: @escaping DrawableSizeWillChange, draw: @escaping Draw) {
        self.setup = setup
        self.drawableSizeWillChange = drawableSizeWillChange
        self.draw = draw
    }

    public var body: some View {
        Group {
            if let error {
                ContentUnavailableView(String(describing: error), systemImage: "exclamationmark.triangle")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                ViewAdaptor<MTKView> {
                    let view = MTKView()
                    model.view = view
                    view.device = device
                    view.delegate = model
                    #if os(macOS)
                    view.layer?.isOpaque = false
                    #endif
                    return view
                } update: { _ in
                }
                .onAppear {
                    model.setup = setup
                    model.drawableSizeWillChange = drawableSizeWillChange
                    model.draw = draw
                    model.doSetup()  // TODO: Error handling
                }
            }
        }
        .onChange(of: model.error.0) {
            self.error = model.error.1
        }
    }
}

@Observable
internal class MetalViewModel: NSObject, MTKViewDelegate {
    var view: MTKView?
    var setup: MetalView.Setup?
    var drawableSizeWillChange: MetalView.DrawableSizeWillChange?
    var draw: MetalView.Draw?
    var error: (Int, Error?) = (0, nil)

    override init() {
//        print(#function)
    }

    func doSetup() {
        guard let view, let device = view.device, let setup else {
            fatalError()
        }
        do {
            var configuration = view.configuration
            try setup(device, &configuration)
            view.configuration = configuration
        }
        catch {
            set(error: error)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let device = view.device, let drawableSizeWillChange else {
            fatalError()
        }
        do {
            var configuration = view.configuration
            try drawableSizeWillChange(device, &configuration, size)
            view.configuration = configuration
            // Automatically mark as needs display if configured to enableSetNeedsDisplay. This should not be controversial.
            if view.enableSetNeedsDisplay {
                #if os(macOS)
                view.needsDisplay = true
                #endif
            }
        }
        catch {
            set(error: error)
        }
    }

    func draw(in view: MTKView) {
        guard let device = view.device, let currentDrawable = view.currentDrawable, let currentRenderPassDescriptor = view.currentRenderPassDescriptor, let draw else {
            fatalError()
        }
        do {
            try draw(device, view.configuration, view.drawableSize, currentDrawable, currentRenderPassDescriptor)
        }
        catch {
            set(error: error)
        }
    }

    func set(error: Error) {
        self.error = (self.error.0 + 1, error)
    }
}

internal extension MTKView {
    var configuration: MetalViewConfiguration {
        get {
            return .init(
                colorPixelFormat: colorPixelFormat,
                clearColor: clearColor,
                depthStencilPixelFormat: depthStencilPixelFormat,
                depthStencilStorageMode: depthStencilStorageMode,
                clearDepth: clearDepth,
                preferredFramesPerSecond: preferredFramesPerSecond,
                enableSetNeedsDisplay: enableSetNeedsDisplay
            )
        }
        set {
            if newValue.colorPixelFormat != colorPixelFormat {
                colorPixelFormat = newValue.colorPixelFormat
            }
            if SIMD4(newValue.clearColor) != SIMD4(clearColor) {
                clearColor = newValue.clearColor
            }
            if newValue.depthStencilPixelFormat != depthStencilPixelFormat {
                depthStencilPixelFormat = newValue.depthStencilPixelFormat
            }
            if newValue.depthStencilStorageMode != depthStencilStorageMode {
                depthStencilStorageMode = newValue.depthStencilStorageMode
            }
            if newValue.clearDepth != clearDepth {
                clearDepth = newValue.clearDepth
            }
            if newValue.preferredFramesPerSecond != preferredFramesPerSecond {
                preferredFramesPerSecond = newValue.preferredFramesPerSecond
            }
            if newValue.enableSetNeedsDisplay != enableSetNeedsDisplay {
                enableSetNeedsDisplay = newValue.enableSetNeedsDisplay
            }
        }
    }
}
#endif

extension SIMD4<Double> {
    init(_ clearColor: MTLClearColor) {
        self = [clearColor.red, clearColor.green, clearColor.blue, clearColor.alpha]
    }
}
