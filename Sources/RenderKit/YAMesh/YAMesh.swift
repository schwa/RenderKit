import Metal
import MetalKit
import ModelIO
import RenderKitShaders

// TODO: -> Semantics
//struct Semantic: OptionSet, Hashable, Sendable {
//    let rawValue: Int
//
//    static let position          = Self(rawValue: 1 << 0)
//    static let normal            = Self(rawValue: 1 << 1)
//    static let textureCoordinate = Self(rawValue: 1 << 2)
//}

//typealias SemanticSet = Set<Semantic> // TODO: Use BitSet<UIntX>
//
//enum BufferRole: Hashable, Sendable {
//    case indices
//    case vertices(SemanticSet)
//    case other
//}

// MARK: -

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

public struct YAMesh: Identifiable, Labeled {
    public typealias ID = LOLID2

    public var id = ID(prefix: "YAMesh")
    public var label: String?
    public var submeshes: [Submesh]
    public var vertexDescriptor: VertexDescriptor
    public var vertexBufferViews: [BufferView]

    public init(label: String? = nil, submeshes: [Submesh], vertexDescriptor: VertexDescriptor, vertexBufferViews: [BufferView]) {
        self.label = label
        self.submeshes = submeshes
        self.vertexDescriptor = vertexDescriptor
        self.vertexBufferViews = vertexBufferViews
    }

    public struct Submesh: Labeled {
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
}

// MARK: -

public extension YAMesh {
    init(label: String? = nil, indexType: MTLIndexType, indexBufferView: BufferView, indexCount: Int, vertexDescriptor: VertexDescriptor, vertexBufferViews: [BufferView], primitiveType: MTLPrimitiveType) {
        let submesh = Submesh(indexType: indexType, indexBufferView: indexBufferView, indexCount: indexCount, primitiveType: primitiveType)
        self = .init(label: label, submeshes: [submesh], vertexDescriptor: vertexDescriptor, vertexBufferViews: vertexBufferViews)
    }

    init(label: String? = nil, indexType: MTLIndexType, indexBufferView: BufferView, indexCount: Int, vertexDescriptor: VertexDescriptor, vertexBuffer: MTLBuffer, vertexBufferOffset: Int, primitiveType: MTLPrimitiveType) {
        assert(vertexDescriptor.layouts.count == 1)
        self = .init(label: label, indexType: indexType, indexBufferView: indexBufferView, indexCount: indexCount, vertexDescriptor: vertexDescriptor, vertexBufferViews: [BufferView(buffer: vertexBuffer, offset: vertexBufferOffset)], primitiveType: primitiveType)
    }
}

public extension YAMesh {
    static func simpleMesh(label: String? = nil, indices: [UInt16], vertices: [SimpleVertex], primitiveType: MTLPrimitiveType = .triangle, device: MTLDevice) throws -> YAMesh {
        guard let indexBuffer = device.makeBuffer(bytesOf: indices, options: .storageModeShared) else {
            fatalError()
        }
        indexBuffer.label = "\(label ?? "unlabeled YAMesh"):indices"
        let indexBufferView = BufferView(buffer: indexBuffer, offset: 0)
        guard let vertexBuffer = device.makeBuffer(bytesOf: vertices, options: .storageModeShared) else {
            fatalError()
        }
        vertexBuffer.label = "\(label ?? "unlabeled YAMesh"):vertices"
        assert(vertexBuffer.length == vertices.count * 32)
        let vertexBufferView = BufferView(buffer: vertexBuffer, offset: 0)
        let vertexDescriptor = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        return YAMesh(indexType: .uint16, indexBufferView: indexBufferView, indexCount: indices.count, vertexDescriptor: vertexDescriptor, vertexBufferViews: [vertexBufferView], primitiveType: primitiveType)
    }

    static func plane(label: String? = nil, rectangle: CGRect, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws -> YAMesh {
        // Transforms:
        // [1, 0], [0, 1], [0, 0]: XY aligned plane
        // [1, 0], [0, 0], [0, 1]: XZ aligned plane
        // ...

        // 1---3
        // |\  |
        // | \ |
        // |  \|
        // 0---2
        let vertices = [
            rectangle.minXMinY,
            rectangle.minXMaxY,
            rectangle.maxXMinY,
            rectangle.maxXMaxY,
        ]
        .map {
            // TODO; Normal not impacted by transform. It should be.
            SimpleVertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
        }
        return try simpleMesh(label: label, indices: [0, 1, 2, 1, 3, 2], vertices: vertices, device: device)
    }
}

public extension MTLRenderCommandEncoder {
    func setVertexBuffers(_ mesh: YAMesh) {
        for (layout, bufferView) in zip(mesh.vertexDescriptor.layouts, mesh.vertexBufferViews) {
            setVertexBuffer(bufferView.buffer, offset: bufferView.offset, index: layout.bufferIndex)
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

public extension YAMesh {
    init(label: String? = nil, mdlMesh: MDLMesh, device: MTLDevice) throws {
        let mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
        let submeshes = mtkMesh.submeshes.map { mtkSubmesh in
            let indexBufferView = BufferView(label: nil, buffer: mtkSubmesh.indexBuffer.buffer, offset: mtkSubmesh.indexBuffer.offset)
            return Submesh(label: mtkSubmesh.name, indexType: mtkSubmesh.indexType, indexBufferView: indexBufferView, indexCount: mtkSubmesh.indexCount, primitiveType: mtkSubmesh.primitiveType)
        }
        let vertexDescriptor = try VertexDescriptor(mdlMesh.vertexDescriptor)
        let vertexBufferViews = mtkMesh.vertexBuffers.map { BufferView(buffer: $0.buffer, offset: $0.offset) }
        self = .init(label: label, submeshes: submeshes, vertexDescriptor: vertexDescriptor, vertexBufferViews: vertexBufferViews)
    }
}

public extension Shape3D {
    func toYAMesh(allocator: MDLMeshBufferAllocator?, device: MTLDevice) throws -> YAMesh {
        let mdlMesh = self.toMDLMesh(allocator: allocator)
        return try YAMesh(label: "\(type(of: self))", mdlMesh: mdlMesh, device: device)
    }
}
