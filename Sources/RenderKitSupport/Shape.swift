import Everything
import Metal
import ModelIO

public protocol ShapeProtocol {
    func makeMDLMesh(geometryType: MDLGeometryType, allocator: MDLMeshBufferAllocator) throws -> MDLMesh
}

// MARK: -

public struct Sphere: Codable {
    public let extent: SIMD3<Float>
    public let segments: SIMD2<Int>
    public let inwardNormals: Bool

    public init(extent: SIMD3<Float> = [1, 1, 1], segments: SIMD2<Int> = [16, 16], inwardNormals: Bool = false) {
        self.extent = extent
        self.segments = segments
        self.inwardNormals = inwardNormals
    }
}

public extension Sphere {
    init(radius: Float) {
        extent = [radius, radius, radius]
        segments = [16, 16]
        inwardNormals = false
    }
}

extension Sphere: ShapeProtocol {
    public func makeMDLMesh(geometryType: MDLGeometryType, allocator: MDLMeshBufferAllocator) throws -> MDLMesh {
        MDLMesh(sphereWithExtent: extent, segments: SIMD2<UInt32>(segments.map({ UInt32($0) })), inwardNormals: inwardNormals, geometryType: geometryType, allocator: allocator)
    }
}

// MARK: -

public struct Box: Codable {
    public let extent: SIMD3<Float>
    public let segments: SIMD3<Int>
    public let inwardNormals: Bool

    public init(extent: SIMD3<Float> = [1, 1, 1], segments: SIMD3<Int> = [1, 1, 1], inwardNormals: Bool = false) {
        self.extent = extent
        self.segments = segments
        self.inwardNormals = inwardNormals
    }
}

extension Box: ShapeProtocol {
    public func makeMDLMesh(geometryType: MDLGeometryType, allocator: MDLMeshBufferAllocator) throws -> MDLMesh {
        MDLMesh(boxWithExtent: extent, segments: SIMD3<UInt32>(segments.map({ UInt32($0) })), inwardNormals: inwardNormals, geometryType: geometryType, allocator: allocator)
    }
}

// MARK: -

public struct Plane: Codable {
    public let extent: SIMD3<Float>
    public let segments: SIMD2<Int>

    public init(extent: SIMD3<Float>, segments: SIMD2<Int> = [1, 1]) {
        self.extent = extent
        self.segments = segments
    }
}

extension Plane: ShapeProtocol {
    public func makeMDLMesh(geometryType: MDLGeometryType, allocator: MDLMeshBufferAllocator) throws -> MDLMesh {
        MDLMesh(planeWithExtent: extent, segments: SIMD2<UInt32>(segments.map({ UInt32($0) })), geometryType: .triangles, allocator: allocator)
    }
}

public enum KnownShape: Codable {
    case plane(Plane)
    case box(Box)
    case sphere(Sphere)
}
