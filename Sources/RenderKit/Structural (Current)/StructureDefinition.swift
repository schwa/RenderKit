import Everything
import Foundation

public struct StructureDefinition: Identifiable {
    public typealias Key = Shader.TypeKey

    public var id: Key {
        key
    }

    // TODO: Move key out of definition
    public let key: Key
    public let attributes: [Attribute]
    public let attributesByName: [String: Attribute]

    public init(key: Key, attributes: [Attribute]) throws {
        self.key = key
        self.attributes = attributes
        attributesByName = Dictionary(uniqueKeysWithValues: attributes.map { ($0.name, $0) })
    }
}
