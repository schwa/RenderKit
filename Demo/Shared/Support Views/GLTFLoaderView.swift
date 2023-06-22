import Everything
import Foundation
import RenderKit
import SwiftGLTF
import SwiftUI
import UniformTypeIdentifiers
import RenderKitSupport
import RenderKitSceneGraph

struct GLTFLoaderView: View {
    @State
    var fileImporterIsPresented = false

    var body: some View {
        Button("Load") {
            fileImporterIsPresented = true
        }
        .fileImporter(isPresented: $fileImporterIsPresented, allowedContentTypes: [.gltf], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result {
                forceTry {
                    _ = try GLTFLoader(url: urls[0])
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension UTType {
    static let gltf = UTType(filenameExtension: "gltf")!
}

class GLTFLoader {
    let url: URL
    let document: SwiftGLTF.Document

    init(url: URL) throws {
        self.url = url
        let data = try Data(contentsOf: url)
        document = try JSONDecoder().decode(SwiftGLTF.Document.self, from: data)
        let scene = try document.scene.map { try $0.resolve(in: document) } ?? document.scenes.first
        for node in scene?.nodes ?? [] {
            let node = try node.resolve(in: document)
            if let gltfMesh = try node.mesh?.resolve(in: document) {
                print(try makeMesh(gltfMesh))
            }
        }
    }

    let device = MTLCreateYoloDevice()
    var buffers: [SwiftGLTF.URI: MTLBuffer] = [:]

    func makeNode(_ node: SwiftGLTF.Node) throws -> ModelEntity {
//        let modelEntity = ModelEntity(name: node.name, transform: .identity, geometry: <#T##Geometry#>, materials: []])
        unimplemented()
    }

    func makeMesh(_ mesh: SwiftGLTF.Mesh) throws -> Mesh {
        let submeshes: [Mesh.Submesh] = try mesh.primitives.map { primitive in
            let attributes: [(Mesh.Semantic, Mesh.Accessor)] = try primitive.attributes.map { gltfSemantic, accessorIndex in
                let gltfAccessor = try accessorIndex.resolve(in: document)
                let accessor = try makeAccessor(from: gltfAccessor)

                let semantic: Mesh.Semantic
                switch gltfSemantic {
                case .POSITION:
                    semantic = .position
                case .NORMAL:
                    semantic = .normal
                case .TANGENT:
                    semantic = .tangent
                case .TEXCOORD_0:
                    semantic = .texcoord(0)
                case .TEXCOORD_1:
                    semantic = .texcoord(1)
                case .TEXCOORD_2:
                    semantic = .texcoord(2)
                case .COLOR_0:
                    semantic = .color(0)
                case .JOINTS_0:
                    semantic = .joints(0)
                case .WEIGHTS_0:
                    semantic = .weights(0)
                }
                return (semantic, accessor)
            }

            // let material = try primitive.material?.resolve(in: document)
            let indices: Mesh.Accessor
            if let gltfIndices = try primitive.indices?.resolve(in: document) {
                indices = try makeAccessor(from: gltfIndices)
            }
            else {
                unimplemented()
            }
            return Mesh.Submesh(attributes: Dictionary(uniqueKeysWithValues: attributes), indices: indices, material: nil, mode: nil)
        }
        return Mesh(name: mesh.name, submeshes: submeshes)
    }

    func makeAccessor(from gltfAccessor: SwiftGLTF.Accessor) throws -> Mesh.Accessor {
        var bufferView: Mesh.BufferView?
        if let gltfBufferView = try gltfAccessor.bufferView?.resolve(in: document) {
            let gltfBuffer = try gltfBufferView.buffer.resolve(in: document)
            guard let uri = gltfBuffer.uri else {
                fatalError("No URI")
            }
            let buffer = try makeBuffer(uri: uri)
            bufferView = Mesh.BufferView(buffer: buffer, offset: gltfBufferView.byteOffset, length: gltfBufferView.byteLength, stride: gltfBufferView.byteStride)
        }
        let accessor = Mesh.Accessor(bufferView: bufferView, offset: gltfAccessor.byteOffset, componentType: gltfAccessor.componentType, normalized: gltfAccessor.normalized, count: gltfAccessor.count, type: gltfAccessor.type, max: gltfAccessor.max, min: gltfAccessor.min, name: gltfAccessor.name)
        return accessor
    }

    func makeBuffer(uri: SwiftGLTF.URI) throws -> MTLBuffer {
        // TODO: Check scheme.
        if let buffer = buffers[uri] {
            return buffer
        }
        let url = url.deletingLastPathComponent().appendingPathComponent(uri.string)
        let data = try Data(contentsOf: url)
        let buffer = data.withUnsafeBytes { buffer in
            device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count)!
        }
        buffers[uri] = buffer
        return buffer
    }
}

// https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html

struct Mesh {
    var name: String?
    var submeshes: [Submesh]

    struct Material {
        var name: String?
        var pbrMetallicRoughness: PBRMetallicRoughness?
        var normalTexture: Any
        var occlusionTexture: Any
        var emissiveTexture: Any
        var emissiveFactor: SIMD3<Float> = .zero
        var alphaMode: Any
        var alphaCutoff: Float = 0.5
        var doubleSided = false
    }

    struct PBRMetallicRoughness {
        var baseColorFactor: SIMD4<Float> = .one
        var textureInfo: TextureInfo
        var metallicFactor: Float = 1
        var roughnessFactor: Float = 1.0
        var metallicRoughnessTexture: TextureInfo
    }

    struct Texture {
        var sampler: MTLSamplerDescriptor
        var name: String?
    }

    struct TextureInfo {
        let index: MTLTexture
        let textCoord: Int
    }

    struct BufferView {
        var name: String?
        var buffer: MTLBuffer
        var offset: Int // NOTE: Use a range
        var length: Int
        var stride: Int?
    }

    struct Accessor {
        var bufferView: BufferView?
        var offset: Int?
        var componentType: Any
        var normalized = false
        var count: Int
        var type: Any
        var max: [Float]?
        var min: [Float]?
//        var sparse: Any?
        var name: String?
    }

    enum Semantic: Hashable {
        case normal
        case position
        case tangent
        case texcoord(Int)
        case color(Int)
        case joints(Int)
        case weights(Int)
    }

    struct Submesh {
        var attributes: [Semantic: Accessor]
        var indices: Accessor?
        var material: Any?
        var mode: Int?
    }
}
