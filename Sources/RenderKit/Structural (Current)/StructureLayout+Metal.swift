import Everything
import Metal
import ModelIO

extension StructureLayout {
    init(_ descriptor: MDLVertexDescriptor) {
        let vertexAttributes = descriptor.attributes.map { $0 as! MDLVertexAttribute }.filter { $0.format != .invalid }
        let layouts: [AttributeLayout] = vertexAttributes.map { vertexAttribute in
            assert(vertexAttribute.bufferIndex == 0)
            return AttributeLayout(name: vertexAttribute.name, kind: MetalType(vertexAttribute.format), offset: vertexAttribute.offset)
        }
        let stride = (descriptor.layouts[0] as! MDLVertexBufferLayout).stride
        self.init(attributes: layouts, alignment: 0, stride: stride)
    }
}

public extension MTLVertexDescriptor {
    convenience init(structure: StructureDefinition) {
        self.init()
        let layout = structure.metalLayout
        for (index, attribute) in structure.attributes.enumerated() {
            guard let attributeLayout = layout.attributeLayouts[attribute.name] else {
                fatalError("No layout found")
            }
            if let format = MTLVertexFormat(attribute.kind) {
                attributes[index].offset = attributeLayout.offset
                attributes[index].format = format
                attributes[index].bufferIndex = 0
            }
        }
        layouts[0].stride = layout.size
        layouts[0].stepFunction = .perVertex
        layouts[0].stepRate = 1
    }
}

public extension StructureLayout {
    var mdlVertexDescriptor: MDLVertexDescriptor {
        // Something broke.
        unimplemented()
//        let attributes = attributeLayouts.values.map { attribute -> MTLAttributeDescriptor in
//            let format: MTLAttributeFormat
//            switch attribute.kind {
//            case .float3:
//                format = .float3
//            case .float2:
//                format = .float2
//            default:
//                // TODO: Expand
//                unimplemented()
//            }
//            return MTLAttributeDescriptor(format: format, offset: attribute.offset, bufferIndex: 0)
//        }
//        return MDLVertexDescriptor(attributes: attributes)
    }
}

public extension MTLVertexFormat {
    init?(_ kind: MetalType) {
        switch kind {
        case .packed_float2:
            self = .float2
        case .packed_float3:
            self = .float3
        case .packed_float4:
            self = .float4
        default:
            return nil
        }
    }
}
