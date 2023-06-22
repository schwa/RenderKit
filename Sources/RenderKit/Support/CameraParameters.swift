import Foundation
import simd
import SwiftUI

public protocol CameraParametersProtocol {
    var yaw: Float { get }
    var pitch: Float { get }
    var fov: Float { get }
    var near: Float { get }
    var far: Float { get }
}

public extension CameraParametersProtocol {
    func projectionTransform(aspect: Float) -> simd_float4x4 {
        simd_float4x4.perspective(aspect: aspect, fovy: fov, near: near, far: far)
    }
}

public class CameraParameters: ObservableObject, CameraParametersProtocol {
    @Published
    public var yaw: Float

    @Published
    public var pitch: Float

    @Published
    public var fov: Float = (2.0 * .pi) / 5.0

    @Published
    public var near: Float = 1

    @Published
    public var far: Float = 10_000

    public init() {
        yaw = 0
        pitch = 0
    }
}

//public extension simd_float4x4 {
//    static func perspective(aspect: Float, fovy: Float, near: Float, far: Float) -> Self {
//        let yScale = 1 / tan(fovy * 0.5)
//        let xScale = yScale / aspect
//        let zRange = far - near
//        let zScale = -(far + near) / zRange
//        let wzScale = -2 * far * near / zRange
//
//        let P: SIMD4<Float> = [xScale, 0, 0, 0]
//        let Q: SIMD4<Float> = [0, yScale, 0, 0]
//        let R: SIMD4<Float> = [0, 0, zScale, -1]
//        let S: SIMD4<Float> = [0, 0, wzScale, 0]
//
//        return simd_float4x4([P, Q, R, S])
//    }
//}
