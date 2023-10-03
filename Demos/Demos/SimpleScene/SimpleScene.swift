import Metal
import MetalSupport
import SIMDSupport
import simd
import ModelIO
import MetalKit
import SwiftUI
import Algorithms
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

// MARK: -

public struct Model: Identifiable {
    public var id = LOLID2(prefix: "Model")
    public var transform: Transform
    public var color: SIMD4<Float>
    public var mesh: (String, (MTLDevice) throws -> MTKMesh)
    //public var mesh1: (MTLDevice) throws -> Cachable<AnyHashable, MTKMesh>

    public init(transform: Transform, color: SIMD4<Float>, mesh: (String, (MTLDevice) throws -> MTKMesh)) {
        self.transform = transform
        self.color = color
        self.mesh = mesh
    }
}

public struct Panorama: Identifiable {
    public var id = LOLID2(prefix: "Model")
    public var tilesSize: SIMD2<UInt16>
    public var tileTextures: [(MTKTextureLoader) throws -> MTLTexture]
    public var mesh: (MTLDevice) throws -> MTKMesh

    init(tilesSize: SIMD2<UInt16>, tileTextures: [(MTKTextureLoader) throws -> MTLTexture], mesh: @escaping (MTLDevice) throws -> MTKMesh) {
        assert(tileTextures.count == Int(tilesSize.x) * Int(tilesSize.y))
        self.tileTextures = tileTextures
        self.tilesSize = tilesSize
        self.mesh = mesh
    }
}

// MARK: -

public extension SimpleScene {
    static func demo() -> SimpleScene {
        let cone = ("cone", { device in try Cone(extent: [0.5, 1, 0.5], segments: [20, 10]).toMTKMesh(allocator: MTKMeshBufferAllocator(device: device), device: device) })
        let sphere = ("sphere", { device in try Sphere(extent: [0.5, 0.5, 0.5], segments: [20, 10]).toMTKMesh(allocator: MTKMeshBufferAllocator(device: device), device: device) })
        let capsule = ("capsule", { device in try Capsule(extent: [0.25, 1, 0.25], cylinderSegments: [30, 10], hemisphereSegments: 5).toMTKMesh(allocator: MTKMeshBufferAllocator(device: device), device: device) })

        let meshes = [cone, sphere, capsule]

        let xRange = [Float](stride(from: -2, through: 2, by: 1))
        let zRange = [Float](stride(from: 0, through: -10, by: -1))

        let tilesSize: SIMD2<UInt16>
        let tileTextures: [(MTKTextureLoader) throws -> MTLTexture]
        if true {
            tilesSize = [6, 2]
            tileTextures = (1 ... 12).map { index in
                ResourceReference.bundle(.main, name: "perseverance_\(index.formatted(.number.precision(.integerLength(2))))", extension: "ktx")
                //ResourceReference.bundle(.main, name: "Testcard_\(index.formatted(.number.precision(.integerLength(2))))", extension: "ktx")
            }
            .map { resource -> ((MTKTextureLoader) throws -> MTLTexture) in
                return { loader in
                    try loader.newTexture(resource: resource, options: [.textureStorageMode: MTLStorageMode.private.rawValue])
                }
            }
        }
        else {
            tilesSize = [1, 1]
            tileTextures = [ { loader in
                    try loader.newTexture(name: "BlueSkySkybox", scaleFactor: 1, bundle: .main, options: [
                        .textureStorageMode: MTLStorageMode.private.rawValue,
                        .SRGB: true,
                    ])
                }
            ]
        }

        let panorama = Panorama(tilesSize: tilesSize, tileTextures: tileTextures) { device in
            try Sphere(extent: [95, 95, 95], inwardNormals: true).toMTKMesh(allocator: MTKMeshBufferAllocator(device: device), device: device)
        }

        let scene = SimpleScene(
            camera: Camera(transform: .translation([0, 0, 2]), target: [0, 0, -1], projection: .perspective(.init(fovy: .degrees(90), zClip: 0.1 ... 100))),
            light: .init(position: .translation([-2, 2, -1]), color: [1, 1, 1], power: 1),
            ambientLightColor: [0, 0, 0],
            models:
                product(xRange, zRange).map { x, z in
                    let hsv: SIMD3<Float> = [Float.random(in: 0...1), 1, 1]
                    let rgba = SIMD4<Float>(hsv.hsv2rgb(), 1.0)
                    return Model(transform: .translation([x, 0, z]), color: rgba, mesh: meshes.randomElement()!)
                },
            panorama: panorama
        )

        return scene
    }
}
