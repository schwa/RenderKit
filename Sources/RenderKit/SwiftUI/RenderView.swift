import Everything
import Foundation
import Metal
import MetalKit
import SwiftUI

// TODO: COmbine into one

#if os(macOS)
    public struct RenderView: NSViewRepresentable {
        let renderer: DrawableRenderer
        let configureView: (MTKView) throws -> Void

        public func makeCoordinator() -> RenderViewCoordinator {
            RenderViewCoordinator(renderer: renderer)
        }

        public init(device: MTLDevice? = nil, configureView: @escaping (MTKView) throws -> Void = { _ in }, configureRenderer: @escaping (Renderer) throws -> Void) throws {
            let device = device ?? MTLCreateSystemDefaultDevice()!
            renderer = DrawableRenderer(device: device)
            try configureRenderer(renderer)
            self.configureView = configureView
        }

        public init(renderer: DrawableRenderer, configureView: @escaping (MTKView) throws -> Void = { _ in }) throws {
            self.renderer = renderer
            self.configureView = configureView
        }

        public func makeNSView(context: NSViewRepresentableContext<RenderView>) -> MTKView {
            let view = MTKView(frame: .zero, device: renderer.device)
            view.delegate = context.coordinator
            forceTry {
                try configureView(view)
            }
            return view
        }

        public func updateNSView(_ view: MTKView, context: NSViewRepresentableContext<RenderView>) {
            view.colorPixelFormat = .bgra8Unorm_srgb
            view.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // TODO:

            renderer.colorPixelFormat = view.colorPixelFormat
        }
    }

    public class RenderViewCoordinator: NSObject, MTKViewDelegate {
        let renderer: DrawableRenderer

        init(renderer: DrawableRenderer) {
            self.renderer = renderer
        }

        @objc
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.viewport = MTLViewport(originX: 0, originY: 0, width: Double(size.width), height: Double(size.height), znear: 0, zfar: 1)
        }

        @objc
        public func draw(in view: MTKView) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable else {
                return
            }
            forceTry {
                let commandBuffer = try renderer.encode(renderPassDescriptor: renderPassDescriptor)
                commandBuffer.present(currentDrawable)
                commandBuffer.commit()
            }
        }
    }

#elseif os(iOS)
    public struct RenderView: UIViewRepresentable {
        let renderer: DrawableRenderer
        let configureView: (MTKView) throws -> Void

        public func makeCoordinator() -> RenderViewCoordinator {
            RenderViewCoordinator(renderer: renderer)
        }

        public init(device: MTLDevice? = nil, configureView: @escaping (MTKView) throws -> Void = { _ in }, configureRenderer: @escaping (Renderer) throws -> Void) throws {
            let device = device ?? MTLCreateSystemDefaultDevice()!
            renderer = DrawableRenderer(device: device)
            try configureRenderer(renderer)
            self.configureView = configureView
        }

        public init(renderer: DrawableRenderer, configureView: @escaping (MTKView) throws -> Void = { _ in }) throws {
            self.renderer = renderer
            self.configureView = configureView
        }

        public func makeUIView(context: UIViewRepresentableContext<RenderView>) -> MTKView {
            let view = MTKView(frame: .zero, device: renderer.device)
            view.delegate = context.coordinator
            forceTry {
                try configureView(view)
            }
            return view
        }

        public func updateUIView(_ view: MTKView, context: UIViewRepresentableContext<RenderView>) {
            view.colorPixelFormat = .bgra8Unorm_srgb
            view.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // TODO:
            renderer.colorPixelFormat = view.colorPixelFormat
        }
    }

    public class RenderViewCoordinator: NSObject, MTKViewDelegate {
        let renderer: DrawableRenderer

        init(renderer: DrawableRenderer) {
            self.renderer = renderer
        }

        @objc
        public func mtkView(_ view: MTKView, drawableSizeWillChange hexSize: CGSize) {
            renderer.viewport = MTLViewport(originX: 0, originY: 0, width: Double(hexSize.width), height: Double(hexSize.height), znear: -1, zfar: 1)
        }

        @objc
        public func draw(in view: MTKView) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable else {
                return
            }
            forceTry {
                forceTry {
                    let commandBuffer = try renderer.encode(renderPassDescriptor: renderPassDescriptor)
                    commandBuffer.present(currentDrawable)
                    commandBuffer.commit()
                }
            }
        }
    }
#endif // os(macOS)
