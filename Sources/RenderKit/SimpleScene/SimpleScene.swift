import Metal
import MetalSupport
import SIMDSupport
import simd
import ModelIO
import MetalKit
import SwiftUI
import Algorithms

protocol ProjectionProtocol: Equatable {
    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4
}

struct PerspectiveProjection: ProjectionProtocol {
    var fovy: SIMDSupport.Angle<Float>
    var zClip: ClosedRange<Float>

    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        let aspect = viewSize.x / viewSize.y
        return .perspective(aspect: aspect, fovy: fovy.radians, near: zClip.lowerBound, far: zClip.upperBound)
    }
}

struct OrthographicProjection: ProjectionProtocol {
    var left: Float
    var right: Float
    var bottom: Float
    var top: Float
    var near: Float
    var far: Float

    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        .orthographic(left: left, right: right, bottom: bottom, top: top, near: near, far: far)
    }
}

struct Light {
    var position: Transform
    var color: SIMD3<Float>
    var power: Float
}

enum Projection: ProjectionProtocol {
    case perspective(PerspectiveProjection)
    case orthographic(OrthographicProjection)

    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        switch self {
        case .perspective(let projection):
            return projection.matrix(viewSize: viewSize)
        case .orthographic(let projection):
            return projection.matrix(viewSize: viewSize)
        }
    }

    // TODO: Use that macro
    enum Meta: CaseIterable {
        case perspective
        case orthographic
    }

    var meta: Meta {
        switch self {
        case .perspective:
            return .perspective
        case .orthographic:
            return .orthographic
        }
    }
}

struct Model {
    var transform: Transform
    var color: SIMD4<Float>
    var mesh: MTKMesh
}

struct Camera {
    var transform: Transform
    var target: SIMD3<Float> {
        didSet {
            let position = transform.translation // TODO: Scale?
            transform = Transform(look(at: position + target, from: position, up: [0, 1, 0]))
        }
    }
    var projection: Projection
}

extension Camera: Equatable {
}

struct SimpleScene {
    var camera: Camera
    var light: Light
    var ambientLightColor: SIMD3<Float>
    var models: [Model]
}



extension Camera {
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

extension SimpleScene {
    static func demo(device: MTLDevice) throws -> SimpleScene {
        let cone = try MTKMesh(mesh: MDLMesh(coneWithExtent: [0.5, 1, 0.5], segments: [20, 10], inwardNormals: false, cap: true, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device)
        let sphere = try MTKMesh(mesh: MDLMesh(sphereWithExtent: [0.5, 0.5, 0.5], segments: [20, 10], inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device)
        let capsule = try MTKMesh(mesh: MDLMesh(capsuleWithExtent: [0.25, 1, 0.25], cylinderSegments: [30, 10], hemisphereSegments: 5, inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device)

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
