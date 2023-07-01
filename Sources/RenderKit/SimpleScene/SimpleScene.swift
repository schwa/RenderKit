import Metal
import MetalSupport
import SIMDSupport
import simd
import ModelIO
import MetalKit
import SwiftUI

protocol ProjectionProtocol: Equatable {
    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4
}

struct PerspectiveProjection: ProjectionProtocol {
    var fovy: Float
    var zClip: ClosedRange<Float>

    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        let aspect = viewSize.x / viewSize.y
        return .perspective(aspect: aspect, fovy: fovy, near: zClip.lowerBound, far: zClip.upperBound)
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

