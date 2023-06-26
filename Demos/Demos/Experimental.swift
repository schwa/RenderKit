import Foundation
import SwiftUI
import simd
import Everything
import Metal
import ModelIO
import MetalKit

public struct Argument : Equatable, Sendable {
    let bytes: [UInt8]

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public static func float<T>(_ x: T) -> Self where T: BinaryFloatingPoint {
        return withUnsafeBytes(of: x) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float2<T>(_ x: T, _ y: T) -> Self where T: BinaryFloatingPoint {
        return withUnsafeBytes(of: (x, y)) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float3<T>(_ x: T, _ y: T, _ z: T) -> Self where T : BinaryFloatingPoint {
        return withUnsafeBytes(of: (x, y, z)) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float4<T>(_ x: T, _ y: T, _ z: T, _ w: T) -> Self where T : BinaryFloatingPoint {
        return withUnsafeBytes(of: (x, y, z, w)) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float2(_ point: CGPoint) -> Self {
        return .float2(Float(point.x), Float(point.y))
    }

    public static func float2(_ size: CGSize) -> Self {
        return .float2(Float(size.width), Float(size.height))
    }

    public static func float2(_ vector: CGVector) -> Self {
        return .float2(Float(vector.dx), Float(vector.dy))
    }

    public static func floatArray(_ array: [Float]) -> Self {
        array.withUnsafeBytes {
            return Argument(bytes: Array($0))
        }
    }

    public static func color(_ color: Color) -> Self {
        //        let cgColor = color.resolve(in: EnvironmentValues())
        unimplemented()
    }

    public static func colorArray(_ array: [Color]) -> Self {
        unimplemented()
    }

    public static func image(_ image: Image) -> Self {
        unimplemented()
    }

    public static func data(_ data: Data) -> Self {
        unimplemented()
    }
}

extension Array where Element == UInt8 {
    mutating func append <Other>(contentsOf bytes: Other, alignment: Int) where Other: Sequence, Other.Element == UInt8 {
        let alignedPosition = align(offset: count, alignment: alignment)
        append(contentsOf: Array(repeating: 0, count: alignedPosition - count))
        append(contentsOf: bytes)
    }
}

/// An object that provides access to the bytes of a value.
/// Avoids issues where getting the bytes of an onject cast to Any is not the same as getting the bytes to the object
public struct UnsafeBytesAccessor: Sendable {
    private let closure: @Sendable (@Sendable (UnsafeRawBufferPointer) -> Void) -> Void

    public init(_ value: some Any) {
        closure = { (callback: (UnsafeRawBufferPointer) -> Void) in
            Swift.withUnsafeBytes(of: value) { buffer in
                callback(buffer)
            }
        }
    }

    public init(_ value: [some Any]) {
        closure = { (callback: (UnsafeRawBufferPointer) -> Void) in
            value.withUnsafeBytes { buffer in
                callback(buffer)
            }
        }
    }

    public func withUnsafeBytes(_ body: @Sendable (UnsafeRawBufferPointer) -> Void) {
        closure(body)
    }
}


func bytes <T>(of value: T) -> [UInt8] {
    withUnsafeBytes(of: value) { return Array($0) }
}

protocol Shape3D {
    // TODO: this is mediocre.
    func toMDLMesh(extent: SIMD3<Float>, allocator: MDLMeshBufferAllocator?) -> MDLMesh
}

struct Plane: Shape3D {
    func toMDLMesh(extent: SIMD3<Float>, allocator: MDLMeshBufferAllocator?) -> MDLMesh {
        MDLMesh(planeWithExtent: extent, segments: [1,1], geometryType: .triangles, allocator: allocator)
    }
}

extension MTLCommandQueue {
    func withCommandBuffer<R>(drawable: @autoclosure () -> (any MTLDrawable)?, block: (MTLCommandBuffer) throws -> R) rethrows -> R {
        guard let commandBuffer = makeCommandBuffer() else {
            // TODO: Better to throw?
            fatalError("Failed to make command buffer.")
        }
        defer {
            if let drawable = drawable() {
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }
        return try block(commandBuffer)
    }
}

extension MTLCommandBuffer {
    func withRenderCommandEncoder<R>(descriptor: MTLRenderPassDescriptor, block: (MTLRenderCommandEncoder) throws -> R) rethrows -> R{
        guard let renderCommandEncoder = makeRenderCommandEncoder(descriptor: descriptor) else {
            // TODO: Better to throw?
            fatalError("Failed to make render command encoder.")
        }
        defer {
            renderCommandEncoder.endEncoding()
        }
        return try block(renderCommandEncoder)
    }
}

extension MTLRenderCommandEncoder {
    func draw(_ mesh: MTKMesh) {
        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
        }
        for submesh in mesh.submeshes {
            drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
}
