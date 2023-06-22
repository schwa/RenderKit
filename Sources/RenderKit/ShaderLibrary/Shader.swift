import Everything
import Foundation

@dynamicMemberLookup
public struct Shader: Identifiable {
    public enum KeyTag {}
    public typealias Key = Tagged<KeyTag, String>

    public enum TypeKeyTag {}
    public typealias TypeKey = Tagged<TypeKeyTag, String>

    public enum Kind: String {
        case vertex
        case fragment
    }

    public var id: Key {
        name
    }

    public let name: Key
    public let type: Kind

    public struct Parameter: Identifiable {
        public var id: String {
            name
        }

        public enum Kind: String {
            case vertices
            case uniform
            case texture
            case buffer
        }

        public let name: String
        public let index: ParameterIndex
        public let typeName: TypeKey?
        public let kind: Kind

        public init(name: String, index: ParameterIndex, typeName: TypeKey?, kind: Kind) {
            self.name = name
            self.index = index
            self.typeName = typeName
            self.kind = kind
        }
    }

    public let parameters: [Parameter]

    public init(name: Key, type: Kind, parameters: [Parameter]) {
        self.name = name
        self.type = type
        self.parameters = parameters
    }

    public subscript(dynamicMember name: String) -> Parameter {
        guard let parameter = parameters[name] else {
            fatalError("no such parameter in \(self.name) called \(name)")
        }
        return parameter
    }
}

// MARK: -

// TODO: Use Tagged<>
public struct ParameterIndex: RawRepresentable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
