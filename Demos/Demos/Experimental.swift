import Foundation
import SwiftUI
import simd
import Everything

public struct Argument : Equatable, Sendable {
    let bytes: [UInt8]

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public static func float<T>(_ x: T) -> Self where T: BinaryFloatingPoint {
        return withUnsafeBytes(of: x) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float2<T>(_ x: T, _ y: T) -> Self where T: BinaryFloatingPoint {
        return withUnsafeBytes(of: (x, y)) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float3<T>(_ x: T, _ y: T, _ z: T) -> Self where T : BinaryFloatingPoint {
        return withUnsafeBytes(of: (x, y, z)) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float4<T>(_ x: T, _ y: T, _ z: T, _ w: T) -> Self where T : BinaryFloatingPoint {
        return withUnsafeBytes(of: (x, y, z, w)) {
            return Argument(bytes: Array($0))
        }
    }

    public static func float2(_ point: CGPoint) -> Self {
        return .float2(Float(point.x), Float(point.y))
    }

    public static func float2(_ size: CGSize) -> Self {
        return .float2(Float(size.width), Float(size.height))
    }

    public static func float2(_ vector: CGVector) -> Self {
        return .float2(Float(vector.dx), Float(vector.dy))
    }

    public static func floatArray(_ array: [Float]) -> Self {
        array.withUnsafeBytes {
            return Argument(bytes: Array($0))
        }
    }

    public static func color(_ color: Color) -> Self {
        //        let cgColor = color.resolve(in: EnvironmentValues())
        fatalError()
    }

    public static func colorArray(_ array: [Color]) -> Self {
        fatalError()
    }

    public static func image(_ image: Image) -> Self {
        fatalError()
    }

    public static func data(_ data: Data) -> Self {
        fatalError()
    }
}

extension Array where Element == UInt8 {
    mutating func append <Other>(contentsOf bytes: Other, alignment: Int) where Other: Sequence, Other.Element == UInt8 {
        let alignedPosition = align(offset: count, alignment: alignment)
        append(contentsOf: Array(repeating: 0, count: alignedPosition - count))
        append(contentsOf: bytes)
    }
}

/// An object that provides access to the bytes of a value.
/// Avoids issues where getting the bytes of an onject cast to Any is not the same as getting the bytes to the object
public struct UnsafeBytesAccessor: Sendable {
    private let closure: @Sendable (@Sendable (UnsafeRawBufferPointer) -> Void) -> Void

    public init(_ value: some Any) {
        closure = { (callback: (UnsafeRawBufferPointer) -> Void) in
            Swift.withUnsafeBytes(of: value) { buffer in
                callback(buffer)
            }
        }
    }

    public init(_ value: [some Any]) {
        closure = { (callback: (UnsafeRawBufferPointer) -> Void) in
            value.withUnsafeBytes { buffer in
                callback(buffer)
            }
        }
    }

    public func withUnsafeBytes(_ body: @Sendable (UnsafeRawBufferPointer) -> Void) {
        closure(body)
    }
}
