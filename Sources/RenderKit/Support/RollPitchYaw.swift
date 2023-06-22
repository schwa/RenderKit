import simd

public struct RollPitchYaw {
    public var roll: Float
    public var pitch: Float
    public var yaw: Float

    public static let identity = RollPitchYaw(roll: 0, pitch: 0, yaw: 0)

    public var quat: simd_quatf {
        simd_quatf(angle: roll, axis: [0, 0, 1]) * simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }
}
