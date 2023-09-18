import Metal
import MetalSupport
import SIMDSupport
import simd
import ModelIO
import MetalKit
import SwiftUI
import Algorithms

public struct SimpleScene {
    public var camera: Camera
    public var light: Light
    public var ambientLightColor: SIMD3<Float>
    public var models: [Model]
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
}

// MARK: -

public struct Model {
    public var transform: Transform
    public var color: SIMD4<Float>
    public var mesh: (MTLDevice) throws -> MTKMesh
}

// MARK: -

public extension SimpleScene {
    static func demo() -> SimpleScene {
        let cone = { device in try MTKMesh(mesh: MDLMesh(coneWithExtent: [0.5, 1, 0.5], segments: [20, 10], inwardNormals: false, cap: true, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device) }
        let sphere = { device in try MTKMesh(mesh: MDLMesh(sphereWithExtent: [0.5, 0.5, 0.5], segments: [20, 10], inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device) }
        let capsule = { device in try MTKMesh(mesh: MDLMesh(capsuleWithExtent: [0.25, 1, 0.25], cylinderSegments: [30, 10], hemisphereSegments: 5, inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device) }

        let meshes = [cone, sphere, capsule]

        let xRange = Array<Float>(stride(from: -2, through: 2, by: 1))
        let zRange = Array<Float>(stride(from: 0, through: -10, by: -1))

        let scene = SimpleScene(
            camera: Camera(transform: .translation([0, 0, 2]), target: [0, 0, -1], projection: .perspective(.init(fovy: .degrees(90), zClip: 0.1 ... 100))),
            light: .init(position: .translation([-1, 2, 1]), color: [1, 1, 1], power: 1),
            ambientLightColor: [0, 0, 0],
            models:
                product(xRange, zRange).map { x, z in
                    let hsv: SIMD3<Float> = [Float.random(in: 0...1), 1, 1]
                    let rgba = SIMD4<Float>(hsv.hsv2rgb(), 1.0)
                    return Model(transform: .translation([x, 0, z]), color: rgba, mesh: meshes.randomElement()!)
                }
        )
        return scene
    }
}
