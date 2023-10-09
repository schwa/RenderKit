import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import Everything
import MetalSupport
import os
import RenderKit
import LegacyGraphics

public extension SimpleVertex {
    init(position: SIMD3<Float>, normal: SIMD3<Float>, textureCoordinate: SIMD2<Float>) {
        self = .init(position: PackedFloat3(position), normal: PackedFloat3(normal), textureCoordinate: textureCoordinate)
    }
}

public extension PackedFloat3 {
    init(_ value: SIMD3<Float>) {
        self = .init(x: value.x, y: value.y, z: value.z)
    }
}

extension PackedFloat3: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        self = .init(x: elements[0], y: elements[1], z: elements[2])
    }
}

protocol MTLBufferProviding {
    var buffer: MTLBuffer { get }
}

//@available(*, deprecated, message: "Use YAMesh")
//extension SimpleMesh {
//    init(label: String? = nil, rectangle: CGRect, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws {
//        // 1---3
//        // |\  |
//        // | \ |
//        // |  \|
//        // 0---2
//
//        let vertices = [
//            rectangle.minXMinY,
//            rectangle.minXMaxY,
//            rectangle.maxXMinY,
//            rectangle.maxXMaxY,
//        ]
//        .map {
//            // TODO; Normal not impacted by transform. It should be.
//            SimpleVertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
//        }
//        self = try .init(label: label, indices: [0, 1, 2, 1, 3, 2], vertices: vertices, device: device)
//    }
//}

extension YAMesh {
    static func simpleMesh(label: String? = nil, indices: [UInt16], vertices: [SimpleVertex], device: MTLDevice) throws -> YAMesh {
        guard let indexBuffer = device.makeBuffer(bytesOf: indices, options: .storageModeShared) else {
            fatalError()
        }
        let indexBufferView = BufferView(buffer: indexBuffer, offset: 0)
        guard let vertexBuffer = device.makeBuffer(bytesOf: vertices, options: .storageModeShared) else {
            fatalError()
        }
        assert(vertexBuffer.length == vertices.count * 32)
        let vertexBufferView = BufferView(buffer: vertexBuffer, offset: 0)
        let vertexDescriptor = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        return YAMesh(indexType: .uint16, indexBufferView: indexBufferView, indexCount: indices.count, vertexDescriptor: vertexDescriptor, vertexBufferViews: [vertexBufferView], primitiveType: .triangle)
    }

    static func triangle(label: String? = nil, triangle: Triangle, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws -> YAMesh {
        let vertices = [
            triangle.vertex.0,
            triangle.vertex.1,
            triangle.vertex.2,
        ]
        .map {
            // TODO; Normal not impacted by transform. It should be.
            SimpleVertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
        }
        return try YAMesh.simpleMesh(label: label, indices: [0, 1, 2], vertices: vertices, device: device)
    }
}
