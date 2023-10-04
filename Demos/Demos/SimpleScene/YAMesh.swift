import Metal
import MetalKit
import ModelIO
import RenderKit

// TODO: -> Semantics
//struct Semantic: OptionSet, Hashable, Sendable {
//    let rawValue: Int
//
//    static let position          = Self(rawValue: 1 << 0)
//    static let normal            = Self(rawValue: 1 << 1)
//    static let textureCoordinate = Self(rawValue: 1 << 2)
//}

public enum Semantic: Hashable, Sendable {
    case position
    case normal
    case textureCoordinate
}

//typealias SemanticSet = Set<Semantic> // TODO: Use BitSet<UIntX>
//
//enum BufferRole: Hashable, Sendable {
//    case indices
//    case vertices(SemanticSet)
//    case other
//}

// MARK: -

public struct VertexDescriptor: Labeled, Hashable, Sendable {
    public struct Attribute: Hashable, Sendable {
        public var label: String?
        public var semantic: Semantic
        public var format: MTLVertexFormat
        public var offset: Int
        public var bufferIndex: Int
    }

    public struct Layout: Hashable, Sendable {
        public var label: String?
        public var stepFunction: MTLStepFunction
        public var stepRate: Int
        public var stride: Int
    }

    public var label: String?
    public var attributes: [Attribute] = []
    public var layouts: [Layout] = []
}

extension VertexDescriptor: CustomStringConvertible {
    public var description: String {
        "VertexDescriptor(attributes: [\n\t\(attributes.map(\.description).joined(separator: "\n\t"))], layouts: [\(layouts.map(\.description).joined(separator: "\n\t"))\n])"
    }
}

extension VertexDescriptor.Attribute: CustomStringConvertible {
    public var description: String {
        "(label: \(label ?? ""), semantic: \(semantic), format: \(format), offset: \(offset), bufferIndex: \(bufferIndex))"
    }
}

extension VertexDescriptor.Layout: CustomStringConvertible {
    public var description: String {
        "(label: \(label ?? ""), \(stepFunction), \(stepRate), \(stride))"
    }
}

public extension VertexDescriptor {
    var bufferCount: Int {
        Set(attributes.map(\.bufferIndex)).count
    }

    func validate() throws {
    }
    //    open func setPackedStrides()
    //    open func setPackedOffsets()
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
        let layouts: [VertexDescriptor.Layout] = descriptor.layouts.compactMap { layout in
            let layout = layout as! MDLVertexBufferLayout
            if layout.stride == 0 {
                return nil
            }
            return VertexDescriptor.Layout(stepFunction: .perVertex, stepRate: 0, stride: layout.stride)
        }
        self = .init(label: nil, attributes: attributes, layouts: layouts)
        try validate()
    }

    init(_ descriptor: MTLVertexDescriptor) throws {
        fatalError()
    }
}

// MARK: -

public struct BufferView: Labeled {
    public var label: String?
    public var buffer: MTLBuffer
    public var offset: Int

    public init(label: String? = nil, buffer: MTLBuffer, offset: Int) {
        self.label = label
        self.buffer = buffer
        self.offset = offset
    }
}

extension BufferView: CustomStringConvertible {
    public var description: String {
        return "BufferView(label: \"\(label ?? "")\", buffer: \(buffer.gpuAddress, format: .hex), offset: \(offset))"
    }
}

// MARK: -

public struct YAMesh: Labeled {
    public var label: String?
    public var submeshes: [YASubmesh]
    public var vertexDescriptor: VertexDescriptor
    public var vertexBufferViews: [Semantic: BufferView]

    public init(label: String? = nil, submeshes: [YASubmesh], vertexDescriptor: VertexDescriptor, vertexBufferViews: [Semantic: BufferView]) {
        self.label = label
        self.submeshes = submeshes
        self.vertexDescriptor = vertexDescriptor
        self.vertexBufferViews = vertexBufferViews
    }
}

public struct YASubmesh: Labeled {
    public var label: String?
    public var indexType: MTLIndexType
    public var indexBufferView: BufferView
    public var indexCount: Int
    public var primitiveType: MTLPrimitiveType

    public init(label: String? = nil, indexType: MTLIndexType, indexBufferView: BufferView, indexCount: Int, primitiveType: MTLPrimitiveType) {
        self.label = label
        self.indexType = indexType
        self.indexBufferView = indexBufferView
        self.indexCount = indexCount
        self.primitiveType = primitiveType
    }
}

// MARK: -

public extension YAMesh {
    init(label: String? = nil, indexType: MTLIndexType, indexBufferView: BufferView, indexCount: Int, vertexDescriptor: VertexDescriptor, vertexBufferViews: [Semantic: BufferView], primitiveType: MTLPrimitiveType) {
        let submesh = YASubmesh(indexType: indexType, indexBufferView: indexBufferView, indexCount: indexCount, primitiveType: primitiveType)
        self = .init(label: label, submeshes: [submesh], vertexDescriptor: vertexDescriptor, vertexBufferViews: vertexBufferViews)
    }

    init(label: String? = nil, indexType: MTLIndexType, indexBufferView: BufferView, indexCount: Int, vertexDescriptor: VertexDescriptor, vertexBuffer: MTLBuffer, vertexBufferOffset: Int, primitiveType: MTLPrimitiveType) {
        assert(vertexDescriptor.bufferCount == 1)
        let vertexBufferViewss = Dictionary(uniqueKeysWithValues: vertexDescriptor.attributes.map({ ($0.semantic, BufferView(buffer: vertexBuffer, offset: vertexBufferOffset)) }))
        self = .init(label: label, indexType: indexType, indexBufferView: indexBufferView, indexCount: indexCount, vertexDescriptor: vertexDescriptor, vertexBufferViews: vertexBufferViewss, primitiveType: primitiveType)
    }
}

public extension MTLRenderCommandEncoder {
    func setVertexBuffer(_ mesh: YAMesh, startingIndex: Int) {
        // TODO: this involves too many allocs.
        let bufferViews: [Int: BufferView] = mesh.vertexDescriptor.attributes.reduce(into: [:]) { partialResult, attribute in
            let vertexBufferView = mesh.vertexBufferViews[attribute.semantic]!
            assert(partialResult[attribute.bufferIndex] == nil || partialResult[attribute.bufferIndex]?.buffer === vertexBufferView.buffer)
            assert(partialResult[attribute.bufferIndex] == nil || partialResult[attribute.bufferIndex]?.offset == vertexBufferView.offset)
            partialResult[attribute.bufferIndex] = vertexBufferView
        }
        for (index, bufferView) in bufferViews {
            setVertexBuffer(bufferView.buffer, offset: bufferView.offset, index: index)
        }
    }

    func draw(_ mesh: YAMesh) {
        for submesh in mesh.submeshes {
            drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBufferView.buffer, indexBufferOffset: submesh.indexBufferView.offset)
        }
    }

    func draw(_ mesh: YAMesh, instanceCount: Int) {
        for submesh in mesh.submeshes {
            drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBufferView.buffer, indexBufferOffset: submesh.indexBufferView.offset, instanceCount: instanceCount)
        }
    }
}

extension YAMesh {
    init(_ mesh: SimpleMesh) {
        fatalError()
        let descriptor = VertexDescriptor() // TODO:
        self = .init(
            label: mesh.label,
            indexType: mesh.indexType,
            indexBufferView: .init(
                buffer: mesh.indexBuffer,
                offset: mesh.indexBufferOffset
            ),
            indexCount: mesh.indexCount,
            vertexDescriptor: descriptor,
            vertexBuffer: mesh.vertexBuffer,
            vertexBufferOffset: mesh.vertexBufferOffset,
            primitiveType: mesh.primitiveType
        )
    }
}

public extension YAMesh {
    init(_ mdlMesh: MDLMesh, device: MTLDevice) throws {
        let mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
        let submeshes = mtkMesh.submeshes.map { mtkSubmesh in
            let indexBufferView = BufferView(label: nil, buffer: mtkSubmesh.indexBuffer.buffer, offset: mtkSubmesh.indexBuffer.offset)
            return YASubmesh(label: mtkSubmesh.name, indexType: mtkSubmesh.indexType, indexBufferView: indexBufferView, indexCount: mtkSubmesh.indexCount, primitiveType: mtkSubmesh.primitiveType)
        }
        let vertexDescriptor = try VertexDescriptor(mdlMesh.vertexDescriptor)

        var vertexBufferViews: [Semantic: BufferView] = [:]
        for attribute in vertexDescriptor.attributes {
            let mtkBuffer = mtkMesh.vertexBuffers[attribute.bufferIndex]
            vertexBufferViews[attribute.semantic] = .init(buffer: mtkBuffer.buffer, offset: mtkBuffer.offset)
        }
        self = .init(label: nil, submeshes: submeshes, vertexDescriptor: vertexDescriptor, vertexBufferViews: vertexBufferViews)
    }
}

public extension Shape3D {
    func toYAMesh(allocator: MDLMeshBufferAllocator?, device: MTLDevice) throws -> YAMesh {
        let mdlMesh = self.toMDLMesh(allocator: allocator)
        return try YAMesh(mdlMesh, device: device)
    }
}
