import SwiftUI
import MetalKit
import Foundation
import SwiftGLTF
import RenderKit

struct GLTFView: View {
    init() {
        try! gltfTest()
    }

    var body: some View {
        Text("hello")
    }
}

func gltfTest() throws {
    let device = MTLCreateSystemDefaultDevice()!
    let url = Bundle.main.url(forResource: "BarramundiFish", withExtension: "glb")!
    let container = try Container(url: url)
    let document = container.document
    let node = try document.scenes[0].nodes[0].resolve(in: document)
    let mesh = try node.mesh!.resolve(in: document)
    print(mesh)
//    let material = try mesh.primitives[0].material!.resolve(in: document)
//    let baseTexture = try material.pbrMetallicRoughness!.baseColorTexture!.index.resolve(in: document)

    assert(mesh.primitives.count == 1)
    let primitive = mesh.primitives.first!

    //    var buffers: [MTLBuffer] = try document.buffers.map { buffer in
    //        let data = try container.data(for: buffer)
    //        return device.makeBuffer(data: data, options: [])!
    //    }

    var mtlBuffers: [Index<Buffer>: MTLBuffer] = [:]
    var descriptor = VertexDescriptor()

    func makeBuffer(for buffer: Index<Buffer>) -> MTLBuffer {
        let data = try! container.data(for: buffer)
        return device.makeBuffer(data: data, options: [])!
    }

    var buffersViews: [Semantic: BufferView] = [:]

    let semantics: [(SwiftGLTF.Mesh.Primitive.Semantic, Semantic, Int)] = [
        (.POSITION, .position, 0),
        (.NORMAL, .normal, 1),
        (.TEXCOORD_0, .textureCoordinate, 2),
    ]
    for (gltfSemantic, semantic, index) in semantics {
        guard let accessor = try primitive.attributes[gltfSemantic]?.resolve(in: document) else {
            continue
        }
        assert(accessor.byteOffset == 0)
        let bufferView = try accessor.bufferView!.resolve(in: document)
        assert(bufferView.byteStride == nil)
        var mtlBuffer: MTLBuffer! = mtlBuffers[bufferView.buffer]
        if mtlBuffer == nil {
            mtlBuffer = makeBuffer(for: bufferView.buffer)
            mtlBuffers[bufferView.buffer] = mtlBuffer
        }
        buffersViews[semantic] = .init(buffer: mtlBuffer, offset: bufferView.byteOffset)

        descriptor.attributes.append(.init(semantic: semantic, format: accessor.vertexFormat!, offset: 0, bufferIndex: index))
    }

    let accessor = try primitive.indices!.resolve(in: document)
    let bufferView = try accessor.bufferView!.resolve(in: document)
    assert(bufferView.byteStride == nil)
    var mtlBuffer: MTLBuffer! = mtlBuffers[bufferView.buffer]
    if mtlBuffer == nil {
        mtlBuffer = makeBuffer(for: bufferView.buffer)
        mtlBuffers[bufferView.buffer] = mtlBuffer
    }
    let indexBufferView = BufferView(buffer: mtlBuffer, offset: bufferView.byteOffset)
    let yaMesh = YAMesh(indexType: .uint16, indexBufferView: indexBufferView, indexCount: 0, vertexDescriptor: descriptor, vertexBufferViews: buffersViews, primitiveType: .triangle)
    //print(yaMesh)

    let cube = try Cube().toYAMesh(allocator: MTKMeshBufferAllocator(device: device), device: device)
    print(cube)
}

extension SwiftGLTF.Accessor {
    var vertexFormat: MTLVertexFormat? {
        switch (componentType, type) {
        case (.FLOAT, .SCALAR):
            return .float
        case (.FLOAT, .VEC2):
            return .float2
        case (.FLOAT, .VEC3):
            return .float3
        case (.FLOAT, .VEC4):
            return .float4
        default:
            fatalError() // MORE TO DO
        }
    }
}

//struct GLTFResourceSpecifier: Equatable, Sendable {
//    enum Part: Hashable, Sendable {
//        case buffer(Buffer)
//        case bufferView(BufferView)
//    }
//
//    var document: SwiftGLTF.Document
//    var part: Part
//}
//
//extension GLTFResourceSpecifier: SynchronousLoadable {
//    func load(_ parameter: ()) throws -> Data {
//        fatalError()
//    }
//}

extension MTLDevice {
    func makeBuffer(data: Data, options: MTLResourceOptions) -> MTLBuffer? {
        return data.withUnsafeBytes { buffer in
            return makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: options)
        }
    }
}
