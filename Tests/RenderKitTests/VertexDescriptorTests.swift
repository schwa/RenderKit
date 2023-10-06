import XCTest
@testable import RenderKit

final class VertexDescriptorTests: XCTestCase {
    func testVertexDescriptor() throws {
        let d = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        XCTAssertEqual(d.bufferCount, 1)
        XCTAssertEqual(d.attributes[0], .init(semantic: .position, format: .float3, offset: 0, bufferIndex: 0))
        XCTAssertEqual(d.attributes[1], .init(semantic: .normal, format: .float3, offset: 12, bufferIndex: 0))
        XCTAssertEqual(d.attributes[2], .init(semantic: .textureCoordinate, format: .float2, offset: 24, bufferIndex: 0))
        XCTAssertEqual(d.layouts[0], .init(stepFunction: .perVertex, stepRate: 1, stride: 32))

        let mtl = MTLVertexDescriptor(d)
        XCTAssertEqual(mtl.attributes[0].format, .float3)
        XCTAssertEqual(mtl.attributes[0].offset, 0)
        XCTAssertEqual(mtl.attributes[0].bufferIndex, 0)
        XCTAssertEqual(mtl.attributes[1].format, .float3)
        XCTAssertEqual(mtl.attributes[1].offset, 12)
        XCTAssertEqual(mtl.attributes[1].bufferIndex, 0)
        XCTAssertEqual(mtl.attributes[2].format, .float2)
        XCTAssertEqual(mtl.attributes[2].offset, 24)
        XCTAssertEqual(mtl.attributes[2].bufferIndex, 0)
        XCTAssertEqual(mtl.layouts[0].stepFunction, .perVertex)
        XCTAssertEqual(mtl.layouts[0].stepRate, 1)
        XCTAssertEqual(mtl.layouts[0].stride, 32)

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
    }
}

public struct VertexDescriptor2: Labeled, Hashable, Sendable {
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

    public init(label: String? = nil, layouts: [Layout]) {
        assert(Set(layouts.map(\.bufferIndex)).count == layouts.count)
        self.label = label
        self.layouts = layouts
    }
}
