import Foundation
import simd
import SIMDSupport
import UnsafeConformances

public enum Projection: Equatable, Codable {
    public static let identity = Projection.matrix(.identity)

    case matrix(simd_float4x4)
    case orthographic(Orthographic)
    case perspective(Perspective)

    public func _matrix(aspectRatio: Float) -> simd_float4x4 {
        switch self {
        case .matrix(let value):
            return value
        case .orthographic(let value):
            return value.matrix(aspectRatio: aspectRatio)
        case .perspective(let value):
            return value.matrix(aspectRatio: aspectRatio)
        }
    }
}

public struct Orthographic: Equatable, Hashable, Codable {
    public var left: Float
    public var right: Float
    public var bottom: Float
    public var top: Float
    public var near: Float
    public var far: Float

    public init(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        self.left = left
        self.right = right
        self.bottom = bottom
        self.top = top
        self.near = near
        self.far = far
    }

    public func matrix(aspectRatio: Float) -> simd_float4x4 {
        simd_float4x4.orthographic(left: left, right: right, bottom: bottom, top: top, near: near, far: far)
    }
}

public struct Perspective: Equatable, Hashable, Codable {
    public var fovy: Angle<Float>
    public var near: Float
    public var far: Float

    public init(fovy: Angle<Float>, near: Float, far: Float) {
        self.fovy = fovy
        self.near = near
        self.far = far
    }

    public func matrix(aspectRatio: Float) -> simd_float4x4 {
        let t = simd_float4x4.perspective(aspect: aspectRatio, fovy: fovy.radians, near: near, far: far)
        return t
    }
}
