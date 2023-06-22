import Everything
import Foundation
import Metal
import MetalKit
import ModelIO

public protocol GeometryProtocol {
    func draw(on renderCommandEncoder: MTLRenderCommandEncoder)
}

public extension MTLRenderCommandEncoder {
    func draw(geometry: some GeometryProtocol) {
        geometry.draw(on: self)
    }
}

// MARK: -

public enum GeometryProvider: Codable {
    case url(url: URL)
    case resource(name: String, bundleSpecifier: BundleSpecifier?)
    case shape(shape: KnownShape)
}
