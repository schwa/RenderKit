import Metal
import simd

// TODO: Work with modern Swift constructs
// TODO: Work with metal only types like packed vs non packed simd

public struct VertexDescriptorBuilder {
    public var attributes: [(format: MTLVertexFormat, size: Int)] = []

    public init() {
    }

    public mutating func addAttribute(format: MTLVertexFormat, size: Int) {
        attributes.append((format, size))
    }

    public mutating func addAttribute<Root>(for keyPath: KeyPath<Root, SIMD2<Float>>) {
        addAttribute(format: MTLVertexFormat.float2, size: MemoryLayout<Float>.size * 2)
    }

    public mutating func addAttribute<Root>(for keyPath: KeyPath<Root, SIMD3<Float>>) {
        addAttribute(format: MTLVertexFormat.float3, size: MemoryLayout<Float>.size * 3)
    }

    public mutating func addAttribute<Root>(for keyPath: KeyPath<Root, SIMD4<Float>>) {
        addAttribute(format: MTLVertexFormat.float4, size: MemoryLayout<Float>.size * 4)
    }

    public var vertexDescriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        var offset: Int = 0
        for (index, attribute) in attributes.enumerated() {
            descriptor.attributes[index].offset = offset
            descriptor.attributes[index].format = attribute.format
            offset += attribute.size
        }
        descriptor.layouts[0].stride = offset
        return descriptor
    }
}
