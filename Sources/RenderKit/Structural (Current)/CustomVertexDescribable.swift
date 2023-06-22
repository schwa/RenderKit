import Metal
import simd

public protocol CustomVertexDescribable {
    static var vertexDescriptor: MTLVertexDescriptor { get }
}

extension SIMD2: CustomVertexDescribable where Scalar == Float {
    public static var vertexDescriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].format = MTLVertexFormat.float2
        descriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        return descriptor
    }
}

extension SIMD3: CustomVertexDescribable where Scalar == Float {
    public static var vertexDescriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].format = MTLVertexFormat.float3
        descriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        return descriptor
    }
}

extension SIMD4: CustomVertexDescribable where Scalar == Float {
    public static var vertexDescriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].format = MTLVertexFormat.float4
        descriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride
        return descriptor
    }
}
