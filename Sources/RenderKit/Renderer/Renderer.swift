import Everything
import Foundation
import Metal
import MetalKit

public protocol Renderer: AnyObject {
    var device: MTLDevice { get }
    var viewport: MTLViewport { get } // TODO: Remove?
    var commandQueue: MTLCommandQueue { get }

    func add<T>(subrenderer: T) where T: Subrenderer
    func remove<T>(subrenderer: T) where T: Subrenderer
    func invalidateCacheFor<T>(subrenderer: T) where T: Subrenderer
}

// MARK: -

// Rename to "pass"?
public protocol Subrenderer: Identifiable {
    func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor
    func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws
}

public struct AnySubrenderer: Subrenderer {
    public let id: AnyHashable

    let _makePipelineDescriptor: (Renderer) throws -> MTLRenderPipelineDescriptor
    let _encode: (Renderer, MTLRenderCommandEncoder) throws -> Void

    public init<T>(_ base: T) where T: Subrenderer {
        id = AnyHashable(base.id)
        _makePipelineDescriptor = { renderer in
            try base.makePipelineDescriptor(renderer: renderer)
        }
        _encode = { renderer, commandEncoder in
            try base.encode(renderer: renderer, commandEncoder: commandEncoder)
        }
    }

    public func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        try _makePipelineDescriptor(renderer)
    }

    public func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        try _encode(renderer, commandEncoder)
    }
}
