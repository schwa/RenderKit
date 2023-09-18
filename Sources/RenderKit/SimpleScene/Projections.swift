import simd
import SIMDSupport

public protocol ProjectionProtocol: Equatable {
    func matrix(viewSize: SIMD2<Float>) -> simd_float4x4
}

public struct PerspectiveProjection: ProjectionProtocol {
    public var fovy: SIMDSupport.Angle<Float>
    public var zClip: ClosedRange<Float>

    public func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        let aspect = viewSize.x / viewSize.y
        return .perspective(aspect: aspect, fovy: fovy.radians, near: zClip.lowerBound, far: zClip.upperBound)
    }
}

public struct OrthographicProjection: ProjectionProtocol {
    public var left: Float
    public var right: Float
    public var bottom: Float
    public var top: Float
    public var near: Float
    public var far: Float

    public func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        .orthographic(left: left, right: right, bottom: bottom, top: top, near: near, far: far)
    }
}

public enum Projection: ProjectionProtocol {
    case perspective(PerspectiveProjection)
    case orthographic(OrthographicProjection)

    public func matrix(viewSize: SIMD2<Float>) -> simd_float4x4 {
        switch self {
        case .perspective(let projection):
            return projection.matrix(viewSize: viewSize)
        case .orthographic(let projection):
            return projection.matrix(viewSize: viewSize)
        }
    }

    // TODO: Use that macro
    public enum Meta: CaseIterable {
        case perspective
        case orthographic
    }

    public var meta: Meta {
        switch self {
        case .perspective:
            return .perspective
        case .orthographic:
            return .orthographic
        }
    }
}
