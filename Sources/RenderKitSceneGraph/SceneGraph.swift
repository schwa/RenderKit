import Combine
import Darwin
import Everything
import Metal
import MetalKit
import ModelIO
import SIMDSupport
import SwiftUI
import RenderKit
import RenderKitSupport

public class SceneGraph: ObservableObject {
    public var cameraController: CameraController
    public var camera: Camera
    public var lightingModel: BlinnPhongLightingModel
    public var scene: SceneNode

    public init(cameraController: CameraController, camera: Camera, scene: SceneNode, lightingModel: BlinnPhongLightingModel) {
        self.cameraController = cameraController
        self.camera = camera
        self.scene = scene
        self.lightingModel = lightingModel
        self.cameraController.camera = camera
    }
}

// MARK: -

public class CameraController: Identifiable {
    public var id = UUID().uuidString

    public var position: SIMD3<Float> {
        didSet {
            guard oldValue != position else {
                return
            }
            updateCamera()
        }
    }

    public var target: SIMD3<Float> {
        didSet {
            guard oldValue != target else {
                return
            }
            updateCamera()
        }
    }

    public var camera: Camera? {
        didSet {
            guard oldValue !== camera else {
                return
            }
            updateCamera()
        }
    }

    public var absoluteTarget: SIMD3<Float> {
        position + target
    }

    public init(position: SIMD3<Float>, target: SIMD3<Float>, camera: Camera?) {
        self.position = position
        self.target = target
        self.camera = camera
    }

    func updateCamera() {
        camera?.transform = transform
    }

    public var transform: Transform {
        Transform(look(at: position + target, from: position, up: [0, 1, 0]))
    }
}

// MARK: -

// https://swiftcraft.io/blog/accesing-enclosing-self-in-a-property-wrapper
// https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md#referencing-the-enclosing-self-in-a-wrapper-type

// TODO: Rename?
@propertyWrapper
public struct MyObservable<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static subscript<O>(_enclosingInstance observed: O, wrapped wrappedKeyPath: ReferenceWritableKeyPath<O, Value>, storage storageKeyPath: ReferenceWritableKeyPath<O, Self>) -> Value where O: Observed {
        get {
            observed[keyPath: storageKeyPath].wrappedValue
        }
        set {
            observed[keyPath: storageKeyPath].wrappedValue = newValue
            observed.didChange(observed)
        }
    }
}

public extension MyObservable where Value: Equatable {
    static subscript<O>(_enclosingInstance observed: O, wrapped wrappedKeyPath: ReferenceWritableKeyPath<O, Value>, storage storageKeyPath: ReferenceWritableKeyPath<O, Self>) -> Value where O: Observed {
        get {
            observed[keyPath: storageKeyPath].wrappedValue
        }
        set {
            guard observed[keyPath: storageKeyPath].wrappedValue != newValue else {
                return
            }
            observed[keyPath: storageKeyPath].wrappedValue = newValue
            observed.didChange(observed)
        }
    }
}

public protocol Observed {
    func didChange(_ object: Self)
}

// MARK: -

public class Node: Identifiable, Observed, CustomInterfaceRepresentable {
    public var id = UUID().uuidString

    @MyObservable
    public var name: String?

    @MyObservable
    public var transform: Transform

    public weak var parent: Node?

    public private(set) var children: [Node]?

    public init(name: String? = nil, transform: Transform = .identity, children: [Node]? = nil) {
        self.name = name
        self.transform = transform
        self.children = children
        for child in children ?? [] {
            child.parent = self
        }
    }

    public func addChild(node: Node) {
        if children == nil {
            children = []
        }
        node.parent = self
        children?.append(node)
    }

    public func didChange(_ object: Node) {
        parent?.didChange(object)
    }

    public var interfaceRepresentation: InterfaceRepresentation {
        .init(icon: Image(systemName: "circle.dotted"), title: String(describing: self), shortDescription: "Node \"\(name ?? "Untitled")\"")
    }
}

public class SceneNode: Node {
    public enum Change {
        case node(Node)
    }

    public var publisher: AnyPublisher<Change, Never> {
        passthrough.eraseToAnyPublisher()
    }

    private let passthrough = PassthroughSubject<Change, Never>()

    override public func didChange(_ object: Node) {
        passthrough.send(.node(object))
    }

    override public var interfaceRepresentation: InterfaceRepresentation {
        .init(icon: Image(systemName: "globe"), title: String(describing: self), shortDescription: "Scene \"\(name ?? "Untitled")\"")
    }
}

public class ModelEntity: Node {
    @MyObservable
    public var geometry: MetalKitGeometry
    @MyObservable
    public var materials: [MaterialProtocol] // NOTE: Use an AnyMaterial
    @MyObservable
    public var isHidden: Bool
    @MyObservable
    public var selectors: Set<PassSelector>

    public init(name: String? = nil, isHidden: Bool = false, transform: Transform = .identity, selectors: Set<PassSelector> = [], geometry: MetalKitGeometry, material: MaterialProtocol? = nil) {
        self.isHidden = isHidden
        self.geometry = geometry
        materials = material.map { [$0] } ?? []
        self.selectors = selectors

        super.init(name: name, transform: transform)
    }

    override public var interfaceRepresentation: InterfaceRepresentation {
        .init(icon: Image(systemName: "cube.transparent"), title: String(describing: self), shortDescription: "Model Node \"\(name ?? "Untitled")\"")
    }
}

public class Light: Node {
    @MyObservable
    public var lightColor: SIMD3<Float>
    @MyObservable
    public var lightPower: Float

    public init(name: String? = nil, transform: Transform, lightColor: SIMD3<Float>, lightPower: Float) {
        self.lightColor = lightColor
        self.lightPower = lightPower
        super.init(name: name, transform: transform)
    }

    override public var interfaceRepresentation: InterfaceRepresentation {
        .init(icon: Image(systemName: "sun.max"), title: String(describing: self), shortDescription: "Light \"\(name ?? "Untitled")\"")
    }
}

public class Camera: Node {
    @MyObservable
    public var projection: Projection

    public init(name: String? = nil, projection: Projection, transform: Transform = .identity) {
        self.projection = projection
        super.init(name: name, transform: transform)
    }

    override public var interfaceRepresentation: InterfaceRepresentation {
        .init(icon: Image(systemName: "camera"), title: String(describing: self), shortDescription: "Camera \"\(name ?? "Untitled")\"")
    }
}

// MARK: -

// MARK: -

public extension Node {
    func reduceWalk<Value>(_ value: Value, visitor: (inout Value, Node) throws -> Void) rethrows -> Value {
        var value = value
        try walk { node in
            try visitor(&value, node)
        }
        return value
    }

    func walk(_ visitor: (Node) throws -> Void) rethrows {
        try visitor(self)
        for child in children ?? [] {
            try child.walk(visitor)
        }
    }
}

public extension SceneGraph {
    // @available(*, deprecated, message: "Walk the tree.")
    var entities: [ModelEntity] {
        var allNodes: [Node] = []
        scene.walk {
            allNodes.append($0)
        }
        return allNodes.compactMap { $0 as? ModelEntity }
    }
}
