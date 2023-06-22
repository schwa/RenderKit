import Everything
import Foundation

public struct StructureLayout {
    public let alignment: Int
    public let attributeLayouts: [String: AttributeLayout]
    public let size: Int
    public let stride: Int

    public init(attributes: [AttributeLayout], alignment: Int, stride: Int) {
        guard let lastAttribute = attributes.last else {
            fatalError("No attribute?")
        }
        self.alignment = alignment
        attributeLayouts = Dictionary(uniqueKeysWithValues: attributes.map { ($0.name, $0) })
        size = lastAttribute.offset + lastAttribute.kind.size
        self.stride = stride
    }
}

public struct AttributeLayout: Codable {
    public let name: String
    public let kind: MetalType
    public let offset: Int

    enum CodingKeys: CodingKey {
        case name
        case kind
        case offset
    }

    public init(name: String, kind: MetalType, offset: Int) {
        self.name = name
        self.kind = kind
        self.offset = offset
    }

    public init(from decoder: Decoder) throws {
        unimplemented()
    }

    public func encode(to encoder: Encoder) throws {
        unimplemented()
    }
}
