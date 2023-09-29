import SwiftUI
import Everything
import MetalKit
import Observation

public struct MetalView: View {
    public typealias Setup = (MTLDevice, inout Configuration) throws -> Void
    public typealias DrawableSizeWillChange = (MTLDevice, inout Configuration, CGSize) throws -> Void
    public typealias Draw = (MTLDevice, Configuration, CGSize) throws -> Void

    public struct Configuration {
        // TODO: Fully expand this.
        public var colorPixelFormat: MTLPixelFormat
        public var depthStencilPixelFormat: MTLPixelFormat
        public var depthStencilStorageMode: MTLStorageMode
        public var clearDepth: Double
        public var preferredFramesPerSecond: Int
    }

    let device = MTLCreateSystemDefaultDevice()! // TODO: Make Environment.

    @State
    var model: MetalViewModel

    let setup: MetalView.Setup

    init(setup: @escaping Setup, drawableSizeWillChange: @escaping DrawableSizeWillChange, draw: @escaping Draw) {
        self.setup = setup
        model = MetalViewModel(drawableSizeWillChange: drawableSizeWillChange, draw: draw)
    }

    public var body: some View {
        ViewAdaptor<MTKView> {
            let view = MTKView()
            view.device = device
            view.delegate = model
            var configuration = view.configuration
            try! setup(device, &configuration) // TODO: Error handling
            view.configuration = configuration
            return view
        } update: { _ in
        }
    }
}

@Observable
internal class MetalViewModel: NSObject, MTKViewDelegate {
    let drawableSizeWillChange: MetalView.DrawableSizeWillChange
    let draw: MetalView.Draw

    var error: Error? {
        didSet {
            // TODO: Property error handling.
            print("Error: \(error)")
        }
    }

    init(drawableSizeWillChange: @escaping MetalView.DrawableSizeWillChange, draw: @escaping MetalView.Draw) {
        self.drawableSizeWillChange = drawableSizeWillChange
        self.draw = draw
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            guard let device = view.device else {
                fatalError()
            }
            var configuration = view.configuration
            try drawableSizeWillChange(device, &configuration, size)
            view.configuration = configuration
        }
        catch {
            self.error = error
        }
    }

    func draw(in view: MTKView) {
        do {
            guard let device = view.device else {
                fatalError()
            }
            try draw(device, view.configuration, view.drawableSize)
        }
        catch {
            self.error = error
        }
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
