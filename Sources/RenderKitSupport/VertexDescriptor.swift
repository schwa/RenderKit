import Everything
import Foundation
import Metal
import MetalSupport

struct VertexDescriptor {
    struct BufferLayout {
        var stride: Int
        var stepFunction: MTLVertexStepFunction
        var stepRate: Int
    }

    struct Attribute {
        var format: MTLVertexFormat
        var offset: Int
        var bufferIndex: Int
    }

    var layouts: [BufferLayout]
    var attributes: [Attribute]

    init(@VertexDescriptorBuilder _ content: () -> [VertexDescriptor.Attribute]) {
        attributes = content()
        // swiftlint:disable:next sorted_first_last
        let stride = attributes.map { $0.offset + $0.format.size }.sorted().last ?? 0
        layouts = [BufferLayout(stride: stride, stepFunction: .perVertex, stepRate: 0)]
    }
}

func testBuilder() {
    let v1 = VertexDescriptor {
        VertexDescriptorBuilder.PartialAttribute(format: .float3, offset: 0, bufferIndex: 0)
        VertexDescriptorBuilder.PartialAttribute(format: .float3, offset: 0, bufferIndex: 0)
        VertexDescriptorBuilder.PartialAttribute(format: .float2, offset: 0, bufferIndex: 0)
    }
    print(v1)
    let v2 = VertexDescriptor {
        MTLVertexFormat.float3
        MTLVertexFormat.float3
        MTLVertexFormat.float2
    }
    print(v2)
}

// MARK: -

protocol VertexDescriptorAttributeConvertable {
    func toAttribute(offset: Int) -> VertexDescriptor.Attribute
}

extension VertexDescriptor.Attribute: VertexDescriptorAttributeConvertable {
    func toAttribute(offset: Int) -> VertexDescriptor.Attribute {
        self
    }
}

extension MTLVertexFormat: VertexDescriptorAttributeConvertable {
    func toAttribute(offset: Int) -> VertexDescriptor.Attribute {
        VertexDescriptor.Attribute(format: self, offset: offset, bufferIndex: 0)
    }
}

@resultBuilder
enum VertexDescriptorBuilder {
    struct PartialAttribute: VertexDescriptorAttributeConvertable {
        var format: MTLVertexFormat
        var offset: Int?
        var bufferIndex: Int

        func toAttribute(offset: Int) -> VertexDescriptor.Attribute {
            VertexDescriptor.Attribute(format: format, offset: self.offset ?? offset, bufferIndex: bufferIndex)
        }
    }

    static func buildBlock() -> [VertexDescriptor.Attribute] {
        []
    }

    static func buildBlock<V>(_ attributes: V...) -> [VertexDescriptor.Attribute] where V: VertexDescriptorAttributeConvertable {
        var offset = 0
        return attributes.map {
            let attribute = $0.toAttribute(offset: offset)
            offset += attribute.format.size
            return attribute
        }
    }
}

extension MTLVertexDescriptor {
    convenience init(_ other: VertexDescriptor) {
        unimplemented()
    }
}

// Optional(<MTLVertexDescriptorInternal: 0x1308933a0>
//          Buffer 0:
//            stepFunction = MTLVertexStepFunctionPerVertex
//          stride = 34
//          Attribute 0:
//            offset = 0
//          format = MTLAttributeFormatFloat3
//          Attribute 1:
//            offset = 12
//          format = MTLAttributeFormatFloat3
//          Attribute 2:
//            offset = 24
//          format = MTLAttributeFormatFloat2
//          Attribute 3:
//            offset = 32
//          format = MTLAttributeFormatUShort)
