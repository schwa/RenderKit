import Metal
import MetalSupport
import SIMDSupport
import simd
import ModelIO
import MetalKit
import SwiftUI
import RenderKit

public struct SimpleScene {
    public var camera: Camera
    public var light: Light
    public var ambientLightColor: SIMD3<Float>
    public var models: [Model]
    public var panorama: Panorama?

    public init(camera: Camera, light: Light, ambientLightColor: SIMD3<Float>, models: [Model], panorama: Panorama? = nil) {
        self.camera = camera
        self.light = light
        self.ambientLightColor = ambientLightColor
        self.models = models
        self.panorama = panorama
    }
}

// MARK: -

public struct Camera {
    public var transform: Transform
    public var target: SIMD3<Float> {
        didSet {
            let position = transform.translation // TODO: Scale?
            transform = Transform(look(at: position + target, from: position, up: [0, 1, 0]))
        }
    }
    public var projection: Projection

    public init(transform: Transform, target: SIMD3<Float>, projection: Projection) {
        self.transform = transform
        self.target = target
        self.projection = projection
    }
}

extension Camera: Equatable {
}

extension Camera: Sendable {
}

public extension Camera {
    var heading: SIMDSupport.Angle<Float> {
        get {
            let degrees = Angle(from: .zero, to: target.xz).degrees
            return Angle(degrees: degrees)
        }
        set {
            let length = target.length
            target = SIMD3<Float>(xz: SIMD2<Float>(length: length, angle: newValue))
        }
    }
}

// MARK: -

public struct Light {
    public var position: Transform
    public var color: SIMD3<Float>
    public var power: Float

    public init(position: Transform, color: SIMD3<Float>, power: Float) {
        self.position = position
        self.color = color
        self.power = power
    }
}

extension Light: Equatable {
}

extension Light: Sendable {
}

// MARK: -

public struct Model: Identifiable {
    public var id = LOLID2(prefix: "Model")
    public var transform: Transform
    public var material: any Material
    public var mesh: YAMesh

    public init(transform: Transform, material: any Material, mesh: YAMesh) {
        self.transform = transform
        self.material = material
        self.mesh = mesh
    }
}

public struct Panorama: Identifiable {
    public var id = LOLID2(prefix: "Model")
    public var tilesSize: SIMD2<UInt16>
    public var tileTextures: [(MTKTextureLoader) throws -> MTLTexture]
    public var mesh: (MTLDevice) throws -> YAMesh

    init(tilesSize: SIMD2<UInt16>, tileTextures: [(MTKTextureLoader) throws -> MTLTexture], mesh: @escaping (MTLDevice) throws -> YAMesh) {
        assert(tileTextures.count == Int(tilesSize.x) * Int(tilesSize.y))
        self.tileTextures = tileTextures
        self.tilesSize = tilesSize
        self.mesh = mesh
    }
}

public protocol Material: Labeled {
}

public struct UnlitMaterial: Material {
    public var label: String?
    public var baseColorFactor: SIMD4<Float> = .one
    public var baseColorTexture: Texture?
}

public struct FlatMaterial: Material {
    public var label: String?
    public var baseColorFactor: SIMD4<Float> = .one
    public var baseColorTexture: Texture?
}

public struct BlinnPhongMaterial: Material {
    public var label: String?
    public var baseColorFactor: SIMD4<Float> = .one
    public var baseColorTexture: Texture?
}

//struct PBRMaterial: Material {
//    var label: String?
//    var baseColorFactor: SIMD4<Float> = .one
//    var baseColorTexture: Texture?
//    var metallicFactor: Float = 1.0
//    var roughnessFactor: Float = 1.0
//    var metallicRoughnessTexture: Texture?
//    var normalTexture: Texture?
//    var occlusionTexture: Texture?
//}

//struct CustomMaterial: Material {
//    var label: String?
//
//    var vertexShader: String
//    var fragmentShader: String
//}

public struct Texture: Labeled {
    public var label: String?
    public var resource: any ResourceProtocol
    public var options: TextureManager.Options

    public init(label: String? = nil, resource: any ResourceProtocol, options: TextureManager.Options = .init()) {
        self.label = label
        self.resource = resource
        self.options = options
    }
}

public class TextureManager {
    public struct Options {
        public var allocateMipMaps = false
        public var generateMipmaps = false
        public var SRGB = false
        public var textureUsage: MTLTextureUsage = .shaderRead
        public var textureCPUCacheMode: MTLCPUCacheMode = .defaultCache
        public var textureStorageMode: MTLStorageMode = .shared
        public var cubeLayout: MTKTextureLoader.CubeLayout?
        public var origin: MTKTextureLoader.Origin?
        public var loadAsArray = false

        public init() {
        }
    }

    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    private let cache: Cache<AnyHashable, MTLTexture>

    public init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
        self.cache = Cache()
    }

    public func texture(for resource: some ResourceProtocol, options: Options = Options()) throws -> MTLTexture {
        return try cache.get(key: resource) {
            return try textureLoader.newTexture(resource: resource, options: .init(options))
        }
    }
}

extension TextureManager.Options: Hashable {
    public func hash(into hasher: inout Hasher) {
        allocateMipMaps.hash(into: &hasher)
        generateMipmaps.hash(into: &hasher)
        SRGB.hash(into: &hasher)
        textureUsage.rawValue.hash(into: &hasher)
        textureCPUCacheMode.hash(into: &hasher)
        textureStorageMode.rawValue.hash(into: &hasher)
        cubeLayout.hash(into: &hasher)
        origin.hash(into: &hasher)
        loadAsArray.hash(into: &hasher)
    }
}

extension Dictionary where Key == MTKTextureLoader.Option, Value == Any {
    init(_ options: TextureManager.Options) {
        self = [:]
//        // TODO: This is NOT necessarily correct
//        self[.allocateMipmaps] = options.allocateMipMaps
//        self[.generateMipmaps] = options.generateMipmaps
//        self[.SRGB] = options.SRGB
//        self[.textureUsage] = options.textureUsage
//        self[.textureCPUCacheMode] = options.textureCPUCacheMode
//        self[.textureStorageMode] = options.textureStorageMode
//        if let cubeLayout = options.cubeLayout {
//            self[.cubeLayout] = cubeLayout
//        }
//        if let origin = options.origin {
//            self[.origin] = origin
//        }
//        self[.loadAsArray] = options.loadAsArray
    }
}
