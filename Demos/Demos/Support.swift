import Foundation
import MetalKit

extension MTKView {
    var betterDebugDescription: String {
        let attributes: [(String, String?)] = [
            ("delegate", delegate.map { String(describing: $0) }),
            ("device", device?.name ),
            ("currentDrawable", currentDrawable.map { String(describing: $0) }),
            ("framebufferOnly", framebufferOnly.formatted()),
            ("depthStencilAttachmentTextureUsage", String(describing: depthStencilAttachmentTextureUsage)),
            ("multisampleColorAttachmentTextureUsage", String(describing: multisampleColorAttachmentTextureUsage)),

            ("presentsWithTransaction", presentsWithTransaction.formatted()),
            //            ("colorPixelFormat", String(describing: colorPixelFormat)),
            ("depthStencilPixelFormat", String(describing: depthStencilPixelFormat)),
            ("depthStencilStorageMode", String(describing: depthStencilStorageMode)),
            ("sampleCount", sampleCount.formatted()),
            ("clearColor", String(describing: clearColor)),
            ("clearDepth", clearDepth.formatted()),
            ("clearStencil", clearStencil.formatted()),
            //            ("depthStencilTexture", String(describing: depthStencilTexture)),
            ("multisampleColorTexture", String(describing: multisampleColorTexture)),
            ("currentRenderPassDescriptor", String(describing: currentRenderPassDescriptor)),
            ("preferredFramesPerSecond", String(describing: preferredFramesPerSecond)),
            ("enableSetNeedsDisplay", String(describing: enableSetNeedsDisplay)),
            ("autoResizeDrawable", autoResizeDrawable.formatted()),
            ("drawableSize", String(describing: drawableSize)),
            ("preferredDrawableSize", String(describing: preferredDrawableSize)),
            ("preferredDevice", preferredDevice?.name),
            ("isPaused", isPaused.formatted()),
            ("colorspace", String(describing: colorspace)),
        ]
        let formattedAttributes = attributes.compactMap { key, value in
            value.map { value in "\t\(key): \(value)" }
        }
        .joined(separator: ",\n")
        return "\(self) (\n\(formattedAttributes)\n)"
    }
}

struct BooleanFormatStyle: FormatStyle {
    func format(_ value: Bool) -> String {
        return value ? "true" : "false"
    }
}

extension Bool {
    func formatted() -> String {
        return BooleanFormatStyle().format(self)
    }
}
