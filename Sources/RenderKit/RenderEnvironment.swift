import Everything

public struct RenderEnvironment {
    public enum KeyTag {}
    // TODO: replace this with something more akin to SwiftUI EnvironmentKey
    public typealias Key = Tagged<KeyTag, String>
    public typealias Value = ParameterValue

    private var storage: [Key: ParameterValue] = [:]

    public init(_ storage: [RenderEnvironment.Key: ParameterValue] = [:]) {
        self.storage = storage
    }

    public subscript(key: Key) -> Value? {
        get {
            storage[key]
        }
        set {
            storage[key] = newValue
        }
    }

    public mutating func update(_ d: [RenderEnvironment.Key: ParameterValue]) {
        storage.merge(d, uniquingKeysWith: { _, rhs in rhs })
    }
}
