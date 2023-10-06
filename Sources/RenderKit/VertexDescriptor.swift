import Metal
import MetalKit
import ModelIO
import Everything

public enum Semantic: Hashable, Sendable {
    case position
    case normal
    case textureCoordinate
}

public struct VertexDescriptor: Labeled, Hashable, Sendable {
    public struct Attribute: Hashable, Sendable {
        public var label: String?
        public var semantic: Semantic
        public var format: MTLVertexFormat
        public var offset: Int
        public var bufferIndex: Int

        public init(label: String? = nil, semantic: Semantic, format: MTLVertexFormat, offset: Int, bufferIndex: Int) {
            self.label = label
            self.semantic = semantic
            self.format = format
            self.offset = offset
            self.bufferIndex = bufferIndex
        }
    }

    public struct Layout: Hashable, Sendable {
        public var label: String?
        public var stepFunction: MTLVertexStepFunction
        public var stepRate: Int
        public var stride: Int

        public init(label: String? = nil, stepFunction: MTLVertexStepFunction, stepRate: Int, stride: Int) {
            self.label = label
            self.stepFunction = stepFunction
            self.stepRate = stepRate
            self.stride = stride
        }
    }

    public var label: String?
    public var attributes: [Attribute]
    public var layouts: [Int: Layout]

    public init(label: String? = nil, attributes: [Attribute], layouts: [Int: Layout]) {
        self.label = label
        self.attributes = attributes
        self.layouts = layouts
    }

    public static var empty: VertexDescriptor {
        return VertexDescriptor(attributes: [], layouts: [:])
    }
}

// MARK: -

public extension VertexDescriptor {
    var bufferCount: Int {
        Set(attributes.map(\.bufferIndex)).count
    }

    func validate() throws {
    }

    mutating func setPackedOffsets() {
        let bufferIndices = Set(attributes.map(\.bufferIndex))
        for bufferIndex in bufferIndices {
            var currentOffset = 0
            for (index, attribute) in attributes.enumerated() where attribute.bufferIndex == bufferIndex {
                attributes[index].offset = currentOffset
                currentOffset += attribute.format.size
            }
        }
    }

    mutating func setPackedStrides() {
    }
}

// MARK: -

public extension VertexDescriptor {
    init(_ descriptor: MTLVertexDescriptor) throws {
        unimplemented()
    }
}

public extension MTLVertexDescriptor {
    convenience init(_ descriptor: VertexDescriptor) {
        self.init()

        for (index, attribute) in descriptor.attributes.enumerated() {
            self.attributes[index].format = attribute.format
            self.attributes[index].offset = attribute.offset
            self.attributes[index].bufferIndex = attribute.bufferIndex
        }
        for (index, layout) in descriptor.layouts {
            self.layouts[index].stride = layout.stride
            self.layouts[index].stepFunction = layout.stepFunction
            self.layouts[index].stepRate = layout.stepRate
        }
    }
}

public extension VertexDescriptor {
    init(_ descriptor: MDLVertexDescriptor) throws {
        let attributes: [VertexDescriptor.Attribute] = descriptor.attributes.compactMap { attribute in
            let attribute = attribute as! MDLVertexAttribute
            let semantic: Semantic
            switch attribute.name {
            case MDLVertexAttributePosition:
                semantic = .position
            case MDLVertexAttributeNormal:
                semantic = .normal
            case MDLVertexAttributeTextureCoordinate:
                semantic = .textureCoordinate
            case "":
                return nil
            default:
                fatalError("Unhandled name for attribute: \"\(attribute)\".")
            }
            let format = MTLVertexFormat(attribute.format)
            return VertexDescriptor.Attribute(label: attribute.name, semantic: semantic, format: format, offset: attribute.offset, bufferIndex: attribute.bufferIndex)
        }
        unimplemented() // TODO: We need to properly convert.
        let layouts: [VertexDescriptor.Layout] = descriptor.layouts.compactMap { layout in
            let layout = layout as! MDLVertexBufferLayout
            if layout.stride == 0 {
                return nil
            }
            return VertexDescriptor.Layout(stepFunction: .perVertex, stepRate: 0, stride: layout.stride)
        }
        self = .init(label: nil, attributes: attributes, layouts: [:])
        try validate()
    }
}

public extension VertexDescriptor {
    /// Convenience method for creating packed descriptors with common attribute types/sizes...
    static func packed(semantics: [Semantic]) -> VertexDescriptor {
        var descriptor = VertexDescriptor.empty
        for semantic in semantics {
            let format: MTLVertexFormat
            switch semantic {
            case .position, .normal:
                format = .float3
            case .textureCoordinate:
                format = .float2
            }
            descriptor.attributes.append(.init(semantic: semantic, format: format, offset: 0, bufferIndex: 0))
        }
        descriptor.setPackedOffsets()
        descriptor.setPackedStrides()
        return descriptor
    }
}

public extension VertexDescriptor {
    func toSwift() -> String {
        let attributes = attributes.map { attribute in
            ".init(semantic: .\(attribute.semantic), format: .\(attribute.format), offset: \(attribute.offset), bufferIndex: \(attribute.bufferIndex))"
        }
            .joined(separator: ",\n\t\t")

        let layouts = layouts.map { _, layout in
            ".init(stepFunction: .\(layout.stepFunction), stepRate: \(layout.stepRate), stride: \(layout.stride))"
        }
            .joined(separator: ",\n\t\t")

        return """
    VertexDescriptor(
        label: "",
        attributes: [
            \(attributes)
        ],
        layouts: [
            \(layouts)
        ]
    )
    """
    }
}
