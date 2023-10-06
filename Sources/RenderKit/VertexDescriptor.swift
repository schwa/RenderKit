import Metal
import MetalKit
import ModelIO
import Everything

public enum Semantic: Hashable, Sendable {
    case undefined // TODO: Remove
    case position
    case normal
    case textureCoordinate
}

public struct VertexDescriptor: Labeled, Hashable, Sendable {
    public struct Layout: Labeled, Hashable, Sendable {
        public var label: String?
        public var bufferIndex: Int
        public var stride: Int
        public var stepFunction: MTLVertexStepFunction
        public var stepRate: Int
        public var attributes: [Attribute]

        public init(label: String? = nil, bufferIndex: Int, stride: Int, stepFunction: MTLVertexStepFunction, stepRate: Int, attributes: [Attribute]) {
            assert(bufferIndex >= 0)
            assert(bufferIndex >= 0)
            assert(stride >= 0)
            self.label = label
            self.bufferIndex = bufferIndex
            self.stride = stride
            self.stepFunction = stepFunction
            self.stepRate = stepRate
            self.attributes = attributes
        }
    }

    public struct Attribute: Labeled, Hashable, Sendable {
        public var label: String?
        public var semantic: Semantic
        public var format: MTLVertexFormat
        public var offset: Int

        public init(label: String? = nil, semantic: Semantic, format: MTLVertexFormat, offset: Int) {
            assert(offset >= 0)
            self.label = label
            self.semantic = semantic
            self.format = format
            self.offset = offset
        }
    }

    public var label: String?
    public var layouts: [Layout]

    public init(label: String? = nil, layouts: [Layout] = []) {
        assert(Set(layouts.map(\.bufferIndex)).count == layouts.count)
        self.label = label
        self.layouts = layouts
    }
}

/*
 <MTLVertexDescriptorInternal: 0x6000037d9140>
     Buffer 0:
         stepFunction = MTLVertexStepFunctionPerVertex
         stride = 32
         Attribute 0:
             offset = 0
             format = MTLAttributeFormatFloat3
         Attribute 1:
             offset = 12
             format = MTLAttributeFormatFloat3
         Attribute 2:
             offset = 24
             format = MTLAttributeFormatFloat2
*/

extension VertexDescriptor: CustomStringConvertible {
    public var description: String {
        var s = ""
        print("VertexDescriptor \(String(describing: label))", to: &s)
        for (index, layout) in layouts.enumerated() {
            print("\tLayout \(index) \(String(describing: layout.label))", to: &s)
            print("\t\tstepFunction: \(layout.stepFunction)", to: &s)
            print("\t\tstride: \(layout.stride)", to: &s)
            print("\t\tstepRate: \(layout.stepRate)", to: &s)
            print("\t\tbufferIndex: \(layout.bufferIndex)", to: &s)
            for (index, attribute) in layout.attributes.enumerated() {
                print("\t\tattribute \(index) \(String(describing: attribute.label))", to: &s)
                print("\t\t\tsemantic: \(attribute.semantic)", to: &s)
                print("\t\t\toffset: \(attribute.offset)", to: &s)
                print("\t\t\tformat: \(attribute.format)", to: &s)
            }
        }
        return s
    }
}

// MARK: -

public extension VertexDescriptor {
    func validate() throws {
    }

    mutating func setPackedOffsets() {
        layouts = layouts.map { layout in
            var layout = layout
            var nextOffset = 0
            layout.attributes = layout.attributes.map { attribute in
                let offset = nextOffset
                nextOffset += attribute.format.size
                return .init(semantic: attribute.semantic, format: attribute.format, offset: offset)
            }
            return layout
        }
    }

    mutating func setPackedStrides() {
        layouts = layouts.map { layout in
            var layout = layout
            if let lastAttribute = layout.attributes.last {
                layout.stride = lastAttribute.offset + lastAttribute.format.size
            }
            return layout
        }
    }
}

// MARK: -

public extension VertexDescriptor {
    init(_ mtlDescriptor: MTLVertexDescriptor) throws {
        // From "Metal feature set tables"
        let maxBufferArgumentEntriesCount = 31
        let maxVertexAttributesCount = 31
        let layouts: [Layout] = (0 ..< maxBufferArgumentEntriesCount).compactMap { bufferIndex in
            let mtlLayout = mtlDescriptor.layouts[bufferIndex]!
            guard mtlLayout.stride != 0 else {
                return nil
            }
            let attributes: [Attribute] = (0 ..< maxVertexAttributesCount).compactMap { index in
                let mtlAttribute = mtlDescriptor.attributes[index]!
                guard mtlAttribute.format != .invalid else {
                    return nil
                }
                guard mtlAttribute.bufferIndex == bufferIndex else {
                    return nil
                }
                return Attribute(semantic: .undefined, format: mtlAttribute.format, offset: mtlAttribute.offset)
            }
            let layout = Layout(bufferIndex: bufferIndex, stride: mtlLayout.stride, stepFunction: mtlLayout.stepFunction, stepRate: mtlLayout.stepRate, attributes: attributes)
            return layout
        }
        self = .init(label: nil, layouts: layouts)
    }
}

public extension MTLVertexDescriptor {
    convenience init(_ descriptor: VertexDescriptor) {
        self.init()
        var nextAttributeIndex = 0
        for layout in descriptor.layouts {
            layouts[layout.bufferIndex].stride = layout.stride
            layouts[layout.bufferIndex].stepFunction = layout.stepFunction
            layouts[layout.bufferIndex].stepRate = layout.stepRate
            for attribute in layout.attributes {
                attributes[nextAttributeIndex].format = attribute.format
                attributes[nextAttributeIndex].offset = attribute.offset
                attributes[nextAttributeIndex].bufferIndex = layout.bufferIndex
                nextAttributeIndex += 1
            }
        }
    }
}

public extension VertexDescriptor {
    init(_ mdlDescriptor: MDLVertexDescriptor) throws {
        // From "Metal feature set tables"
        let maxBufferArgumentEntriesCount = 31
        let maxVertexAttributesCount = 31
        let layouts: [Layout] = (0 ..< maxBufferArgumentEntriesCount).compactMap { bufferIndex in
            let mdlLayout = mdlDescriptor.layouts[bufferIndex] as! MDLVertexBufferLayout
            guard mdlLayout.stride != 0 else {
                return nil
            }
            let attributes: [Attribute] = (0 ..< maxVertexAttributesCount).compactMap { attributeIndex in
                let mdlAttribute = mdlDescriptor.attributes[attributeIndex] as! MDLVertexAttribute
                guard mdlAttribute.bufferIndex == bufferIndex, mdlAttribute.format != .invalid else {
                    return nil
                }
                let format = MTLVertexFormat(mdlAttribute.format)
                return Attribute(semantic: .undefined, format: format, offset: mdlAttribute.offset)
            }
            return .init(label: nil, bufferIndex: bufferIndex, stride: mdlLayout.stride, stepFunction: .perVertex, stepRate: 1, attributes: attributes)
        }
        self = .init(label: nil, layouts: layouts)
    }
}

public extension VertexDescriptor {
    /// Convenience method for creating packed descriptors with common attribute types/sizes...
    static func packed(label: String? = nil, semantics: [Semantic]) -> VertexDescriptor {
        let attributes: [Attribute] = semantics.map { semantic in
            let format: MTLVertexFormat
            switch semantic {
            case .position, .normal:
                format = .float3
            case .textureCoordinate:
                format = .float2
            default:
                fatalError()
            }
            return .init(semantic: semantic, format: format, offset: 0)
        }
        let layout = Layout(bufferIndex: 0, stride: 0, stepFunction: .perVertex, stepRate: 1, attributes: attributes)
        var descriptor = VertexDescriptor(label: label, layouts: [layout])
        descriptor.setPackedOffsets()
        descriptor.setPackedStrides()
        return descriptor
    }
}

//public extension VertexDescriptor {
//    func toSwift() -> String {
//        let attributes = attributes.map { attribute in
//            ".init(semantic: .\(attribute.semantic), format: .\(attribute.format), offset: \(attribute.offset), bufferIndex: \(attribute.bufferIndex))"
//        }
//            .joined(separator: ",\n\t\t")
//
//        let layouts = layouts.map { _, layout in
//            ".init(stepFunction: .\(layout.stepFunction), stepRate: \(layout.stepRate), stride: \(layout.stride))"
//        }
//            .joined(separator: ",\n\t\t")
//
//        return """
//    VertexDescriptor(
//        label: "",
//        attributes: [
//            \(attributes)
//        ],
//        layouts: [
//            \(layouts)
//        ]
//    )
//    """
//    }
//}
