#if !os(visionOS)
import SwiftUI
import Everything
import MetalKit
import Observation

public struct MetalView: View {
    public typealias Setup = (MTLDevice, inout Configuration) throws -> Void
    public typealias DrawableSizeWillChange = (MTLDevice, inout Configuration, CGSize) throws -> Void
    public typealias Draw = (MTLDevice, Configuration, CGSize, CAMetalDrawable, MTLRenderPassDescriptor) throws -> Void

    public struct Configuration {
        // TODO: Fully expand this.
        public var colorPixelFormat: MTLPixelFormat
        public var depthStencilPixelFormat: MTLPixelFormat
        public var depthStencilStorageMode: MTLStorageMode
        public var clearDepth: Double
        public var preferredFramesPerSecond: Int
    }

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

    init(setup: @escaping Setup, drawableSizeWillChange: @escaping DrawableSizeWillChange, draw: @escaping Draw) {
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
                    guard let device else {
                        fatalError()
                    }
                    let view = MTKView()
                    model.view = view
                    view.device = device
                    view.delegate = model
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
    var configuration: MetalView.Configuration {
        get {
            return .init(
                colorPixelFormat: colorPixelFormat,
                depthStencilPixelFormat: depthStencilPixelFormat,
                depthStencilStorageMode: depthStencilStorageMode,
                clearDepth: clearDepth,
                preferredFramesPerSecond: preferredFramesPerSecond
            )
        }
        set {
            if newValue.colorPixelFormat != colorPixelFormat {
                colorPixelFormat = newValue.colorPixelFormat
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
        }
    }
}
#endif
