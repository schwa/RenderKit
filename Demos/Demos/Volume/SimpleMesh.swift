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

struct SimpleMesh {
    let label: String?
    var indexCount: Int
    var indexBuffer: MTLBuffer
    var vertexBuffer: MTLBuffer

    var primitiveType: MTLPrimitiveType {
        .triangle
    }
    var indexType: MTLIndexType { .uint16 }
    var indexBufferOffset: Int { 0 }
    var vertexBufferOffset: Int { 0 }

    static let vertexDescriptor: MTLVertexDescriptor = {
        assert(MemoryLayout<Vertex>.size == 40)

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stride = 40
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[2].offset = 32
        vertexDescriptor.attributes[2].format = .float2
        return vertexDescriptor
    }()

    init(label: String? = nil, indexCount: Int, indexBuffer: MTLBuffer, vertexBuffer: MTLBuffer) {
        self.label = label
        self.indexCount = indexCount
        self.indexBuffer = indexBuffer
        self.vertexBuffer = vertexBuffer
        if let label {
            indexBuffer.label = "\(label)-indices"
            vertexBuffer.label = "\(label)-vertices"
        }
    }
}

extension SimpleMesh {
    init(label: String? = nil, indices: [UInt16], vertices: [Vertex], device: MTLDevice) throws {
        guard let indexBuffer = device.makeBuffer(bytesOf: indices, options: .storageModeShared) else {
            fatalError()
        }
        guard let vertexBuffer = device.makeBuffer(bytesOf: vertices, options: .storageModeShared) else {
            fatalError()
        }
        assert(vertexBuffer.length == vertices.count * 40)
        self = .init(label: label, indexCount: indices.count, indexBuffer: indexBuffer, vertexBuffer: vertexBuffer)
    }
}

extension SimpleMesh {
    init(label: String? = nil, rectangle: CGRect, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws {
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
            Vertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
        }
        self = try .init(label: label, indices: [0, 1, 2, 1, 3, 2], vertices: vertices, device: device)
    }
}

extension SimpleMesh {
    init(label: String? = nil, triangle: Triangle, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws {
        let vertices = [
            triangle.vertex.0,
            triangle.vertex.1,
            triangle.vertex.2,
        ]
        .map {
            // TODO; Normal not impacted by transform. It should be.
            Vertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
        }
        self = try .init(label: label, indices: [0, 1, 2], vertices: vertices, device: device)
    }
}

extension MTLRenderCommandEncoder {
    func setVertexBuffer(_ mesh: SimpleMesh, index: Int) {
        setVertexBuffer(mesh.vertexBuffer, offset: mesh.vertexBufferOffset, index: index)
    }

    func draw(_ mesh: SimpleMesh) {
        drawIndexedPrimitives(type: mesh.primitiveType, indexCount: mesh.indexCount, indexType: mesh.indexType, indexBuffer: mesh.indexBuffer, indexBufferOffset: mesh.indexBufferOffset)
    }

    func draw(_ mesh: SimpleMesh, instanceCount: Int) {
        drawIndexedPrimitives(type: mesh.primitiveType, indexCount: mesh.indexCount, indexType: mesh.indexType, indexBuffer: mesh.indexBuffer, indexBufferOffset: mesh.indexBufferOffset, instanceCount: instanceCount)
    }
}
