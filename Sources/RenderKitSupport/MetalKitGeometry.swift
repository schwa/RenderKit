import Everything
import Foundation
import Metal
import MetalKit
import ModelIO

public struct MetalKitGeometry: Codable {
    public let provider: GeometryProvider
    public let mesh: MTKMesh

    public init(mesh: MTKMesh, provider: GeometryProvider) {
        self.mesh = mesh
        self.provider = provider
    }

    public init(provider: GeometryProvider, device: MTLDevice) throws {
        switch provider {
        case .url(let url):
            self = try MetalKitGeometry(url: url, device: device, provider: provider)
        case .resource(let name, let bundleSpecifier):
            let bundle: Bundle?
            switch bundleSpecifier {
            case .none, .main:
                bundle = Bundle.main
            case .url(let url):
                bundle = Bundle(url: url)
            case .identifier(let identifier):
                bundle = Bundle(identifier: identifier)
            }
            guard let url = bundle?.url(forResource: name, withExtension: "obj") else {
                fatalError("Could not get url for name \(name)")
            }
            self = try MetalKitGeometry(url: url, device: device, provider: provider)
        case .shape(let shape):
            let mdlMesh: MDLMesh
            let allocator = MTKMeshBufferAllocator(device: device)
            let label: String
            switch shape {
            case .box(let box):
                mdlMesh = try box.makeMDLMesh(geometryType: .triangles, allocator: allocator)
                label = "Box"
            case .plane(let plane):
                mdlMesh = try plane.makeMDLMesh(geometryType: .triangles, allocator: allocator)
                label = "Plane"
            case .sphere(let sphere):
                mdlMesh = try sphere.makeMDLMesh(geometryType: .triangles, allocator: allocator)
                label = "Sphere"
            }
            let mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)

            for vertexBuffer in mtkMesh.vertexBuffers {
                vertexBuffer.buffer.label = "\(label) Vertex Buffer"
            }
            for submesh in mtkMesh.submeshes {
                submesh.indexBuffer.buffer.label = "\(label) Index Buffer"
            }

            assert(mtkMesh.vertexBuffers.count == 1)
            assert(mtkMesh.vertexBuffers[0].offset == 0)
            self = MetalKitGeometry(mesh: mtkMesh, provider: provider)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let provider = try container.decode(GeometryProvider.self)
        self = try MetalKitGeometry(provider: provider, device: MTLCreateYoloDevice())
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(provider)
    }
}

// MARK: -

public extension MetalKitGeometry {
    init(shape: KnownShape, device: MTLDevice) throws {
        self = try .init(provider: .shape(shape: shape), device: device)
    }
}

extension MetalKitGeometry: GeometryProtocol {
    public func draw(on renderCommandEncoder: MTLRenderCommandEncoder) {
        for submesh in mesh.submeshes {
            renderCommandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
}

// MARK: -

public extension MetalKitGeometry {
    init(named name: String, device: MTLDevice) throws {
        let url = Bundle.main.url(forResource: name, withExtension: "obj")!
        self = try MetalKitGeometry(url: url, device: device, provider: .resource(name: name, bundleSpecifier: .main))
    }
}

public extension MetalKitGeometry {
    init(url: URL, device: MTLDevice, provider: GeometryProvider? = nil) throws {
        let allocator = MTKMeshBufferAllocator(device: device)

        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: allocator)
        let meshes = try cast(asset.childObjects(of: MDLMesh.self), as: [MDLMesh].self)
        guard let mesh = meshes.first else {
            fatalError("No mesh found")
        }
        let mtkMesh = try MTKMesh(mesh: mesh, device: device)
        assert(mtkMesh.vertexBuffers.count == 1)
        assert(mtkMesh.vertexBuffers[0].offset == 0)

        let label = url.lastPathComponent

        for vertexBuffer in mtkMesh.vertexBuffers {
            vertexBuffer.buffer.label = "\(label) Vertex Buffer"
        }
        for submesh in mtkMesh.submeshes {
            submesh.indexBuffer.buffer.label = "\(label) Index Buffer"
        }

        self.mesh = mtkMesh
        self.provider = provider ?? .url(url: url)
    }
}
