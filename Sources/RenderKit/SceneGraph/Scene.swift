import Everything
import Foundation
import MetalKit
import RenderKitShaders
import simd
import SwiftUI
import SIMDSupport

// Kombu

public class Scene: ObservableObject {
    @Published
    public var currentCamera: CameraProtocol?

    @Published
    public var rootNode = Entity()

    public init() {
        rootNode.name = "root"
    }
}

// MARK: -

open class Entity: ObservableObject, Identifiable, Equatable, Hashable, CustomStringConvertible, Encodable {
    public var description: String {
        "\(type(of: self)): \(name ?? "")"
    }

    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    public weak var parent: Entity?

    @Published
    public var name: String?

    @Published
    public private(set) var children: [Entity] = []

    @Published
    public var transform = Transform()

    public init() {
    }

    public func addChild(_ child: Entity) {
        assert(children.contains { $0 === child } == false)
        child.parent?.children.removeAll { $0 === child }
        child.parent = self
        children.append(child)
    }

    public func removeChild(_ child: Entity) {
        assert(child.parent === self)
        children.removeAll { $0 === child }
        child.parent = nil
    }

    public func removeFromParent() {
        guard let parent = parent else {
            return
        }
        parent.children.removeAll { $0 === self }
        self.parent = nil
    }

    public func walk(_ f: (Entity) -> Void) {
        f(self)
        for child in children {
            child.walk(f)
        }
    }

    // MARK: -

    enum CodingKeys: CodingKey {
        case name
        case kind
        case children
        case transform
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(String(describing: type(of: self)), forKey: .kind)
        try container.encode(children, forKey: .children)
        try container.encode(transform, forKey: .transform)
    }
}

// MARK: -

public protocol CameraProtocol: Entity {
}

public class PerspectiveCamera: Entity, CameraProtocol {
    @Published
    public var fovy: Float
    @Published
    public var near: Float
    @Published
    public var far: Float

    public init(fovy: Float, near: Float, far: Float) {
        self.fovy = fovy
        self.near = near
        self.far = far
        super.init()
    }

    enum CodingKeys: CodingKey {
        case fovy
        case near
        case far
    }

    override public func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fovy, forKey: .fovy)
        try container.encode(near, forKey: .near)
        try container.encode(far, forKey: .far)
    }
}

// MARK: -

public class ModelEntity: Entity {
    public private(set) var mesh: MTKMesh
    public var material = PhongMaterial(ambientColor: [0.1, 0, 0], diffuseColor: [0.5, 0, 0], specularColor: [1, 1, 1], specularPower: 16)

    public init(mesh: MTKMesh, color: SIMD4<Float>) {
        self.mesh = mesh
        super.init()
    }
}

public class DirectionalLightEntity: Entity {
    public var directionalLight = PhongDirectionalLight(direction: [1, 1, 1], ambientColor: [1, 1, 1], diffuseColor: [1, 1, 1], specularColor: [1, 1, 1])
}

public class AmbientLightEntity: Entity {
//    public var ambientLight = AmbientLight(color: [1, 1, 1])
}
