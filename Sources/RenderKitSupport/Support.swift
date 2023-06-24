import Combine
import Everything
import Foundation
import Metal
import os.log
import simd
import SIMDSupport
import SwiftUI
import MetalSupport

extension Collection {
    var onlyElement: Element {
        if isEmpty {
            fatalError("Collection is empty.")
        }
        if count != 1 {
            fatalError("Collection has more than one element.")
        }
        return first!
    }
}

public enum BundleSpecifier: Codable {
    case url(url: URL)
    case main
    case identifier(identifier: String)
    // TOOD: case bundleRelative(bundle: BundleSpecifier, path: String)

    public init(bundle: Bundle?) {
        if let bundle {
            self = .url(url: bundle.bundleURL)
        }
        else {
            self = .main
        }
    }

    public var bundle: Bundle? {
        switch self {
        case .url(let url):
            return Bundle(url: url)
        case .main:
            return Bundle.main
        case .identifier(let identifier):
            return Bundle(identifier: identifier)
        }
    }
}

let log = OSLog(subsystem: "timeit", category: .pointsOfInterest)
let logger = Logger(subsystem: "timeit", category: "timeit")

public func timeit<R>(_ label: String, closure: () throws -> R) rethrows -> R {
    os_signpost(.begin, log: log, name: "TIMEIT")
    let start = mach_absolute_time()
    defer {
        let end = mach_absolute_time()
        os_signpost(.end, log: log, name: "TIMEIT")
        var info = mach_timebase_info_data_t()
        if mach_timebase_info(&info) != 0 {
            fatalError("Could not get mach_timebase_infothat")
        }
        let nanos = (end - start) * UInt64(info.numer) / UInt64(info.denom)
        logger.debug("\(label, privacy: .public): \(TimeInterval(nanos) / TimeInterval(NSEC_PER_SEC))")
    }
    return try closure()
}

public struct RadiansToAngleConverter: Converter {
    public init() {
    }

    public let convert = { (value: Float) in
        SIMDSupport.Angle(radians: value)
    }

    public let reverse = { (value: SIMDSupport.Angle<Float>) in
        value.radians
    }
}

// MARK: -

public struct IdentifierPath<Base>: Hashable where Base: Hashable {
    public let identifiers: [Base]

    public init(_ identifiers: [Base]) {
        self.identifiers = identifiers
    }

    public init(_ identifiers: Base...) {
        self.identifiers = identifiers
    }
}

public final class RenderLoopTracker {
    public static let shared = RenderLoopTracker()

    private var count = 0
    var lock = OSAllocatedUnfairLock()
    var logging: Logger? // = Everything.logging

    public func push(file: StaticString = #file, line: UInt = #line) {
        lock.withLockUnchecked {
            // swiftlint:disable:next empty_count
            if count == 0 {
                logging?.debug("Entering RenderLoop. \(file)#\(line) \(Thread.current)")
            }
            count += 1
        }
    }

    public func pop(file: StaticString = #file, line: UInt = #line) {
        lock.withLockUnchecked {
            count -= 1
            // swiftlint:disable:next empty_count
            assert(count >= 0)
            // swiftlint:disable:next empty_count
            if count == 0 {
                logging?.debug("Exiting RenderLoop. \(file)#\(line) \(Thread.current)")
            }
        }
    }

    public var isInRenderLoop: Bool {
        lock.withLockUnchecked {
            // swiftlint:disable:next empty_count
            count != 0
        }
    }

    public func withRenderLoop<R>(file: StaticString = #file, line: UInt = #line, _ transaction: () throws -> R) rethrows -> R {
        defer {
            pop(file: file, line: line)
        }
        push(file: file, line: line)
        return try transaction()
    }
}

public func assertNotInRenderLoop(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    if RenderLoopTracker.shared.isInRenderLoop {
        warning("Allocation in render loop \(file):\(line) \(Thread.current) " + message(), file: file, line: line)
    }
}

@MainActor
private var shownWarnings: Set<String> = []

@MainActor
public func warningOnce(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) {
    guard condition() == true else {
        return
    }
    let key = "\(file)#\(line)"
    guard !shownWarnings.contains(key) else {
        return
    }
    let message = message()
    if message.isEmpty {
        print("WARNING: \(file)#\(line)")
    }
    else {
        print("WARNING: \(message), \(file)#\(line)")
    }

    shownWarnings.insert(key)
}

public struct Pair<First, Second> {
    public var first: First
    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension Pair: Equatable where First: Equatable, Second: Equatable {
}

extension Pair: Hashable where First: Hashable, Second: Hashable {
}

public struct DisplayLinkKey: EnvironmentKey {
    public static var defaultValue = DisplayLinkPublisher()
}

public extension EnvironmentValues {
    var displayLink: DisplayLinkPublisher {
        get {
            self[DisplayLinkKey.self]
        }
        set {
            self[DisplayLinkKey.self] = newValue
        }
    }
}

public protocol Labelled {
    var label: String? { get }
}


/// An object that provides access to the bytes of a value.
/// Avoids issues where getting the bytes of an onject cast to Any is not the same as getting the bytes to the object
public struct UnsafeBytesAccessor {
    private let closure: ((UnsafeRawBufferPointer) -> Void) -> Void

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

    public func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) -> Void) {
        closure(body)
    }
}

public extension NSTextCheckingResult {
    func group(named name: String, in string: String) -> String? {
        guard let range = Range(range(withName: name), in: string) else {
            return nil
        }
        return String(string[range])
    }
}

public extension PixelFormat {
    init(mtlPixelFormat: MTLPixelFormat) {
        switch mtlPixelFormat {
        case .bgra8Unorm:
            // Ordinary format with four 8-bit normalized unsigned integer components in BGRA order.
            self = .init(bitsPerComponent: 8, numberOfComponents: 4, alphaInfo: .premultipliedLast, byteOrder: .order32Little, useFloatComponents: false, colorSpace: CGColorSpaceCreateDeviceRGB())

        case .rgba8Unorm:
            // Ordinary format with four 8-bit unsigned integer components in RGBA order.
            self = .init(bitsPerComponent: 8, numberOfComponents: 4, alphaInfo: .premultipliedLast, byteOrder: .order32Big, useFloatComponents: false, colorSpace: CGColorSpaceCreateDeviceRGB())

        case .rgba32Float:
            self = .init(bitsPerComponent: 32, numberOfComponents: 4, alphaInfo: .premultipliedLast, byteOrder: .order32Little, useFloatComponents: true, colorSpace: CGColorSpaceCreateDeviceRGB())

        case .bgra8Unorm_srgb:

            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)

            self = .init(bitsPerComponent: 8, numberOfComponents: 4, alphaInfo: .premultipliedLast, byteOrder: .order32Little, useFloatComponents: false, colorSpace: colorSpace)
        default:
            fatalError("Unexpected case")
        }
    }
}

public extension MTLTexture {
    @available(*, deprecated, message: "TODO: Merge all CGImage functions")
    var cgImage: CGImage {
        let pixelFormat = PixelFormat(mtlPixelFormat: pixelFormat)
        let bitmapDefinition = BitmapDefinition(width: width, height: height, pixelFormat: pixelFormat)
        guard let contents = buffer?.contents() else {
            // Need to blit the texture to a buffer backed texture
            fatalError("Could not get buffer contents")
        }
        let mutableContents = UnsafeMutableRawPointer(contents)
        let p = UnsafeMutableRawBufferPointer(start: mutableContents, count: buffer!.length)
        
        let context = CGContext.bitmapContext(data: p, definition: bitmapDefinition)!
        let image = context.makeImage()!
        return image
    }
    
    @available(*, deprecated, message: "TODO: Merge all CGImage functions")
    var betterCGImage: CGImage {
        let sampleSize = pixelFormat.size!
        let bytesPerRow = width * sampleSize
        let bytesPerImage = height * width * sampleSize
        let length = width * height * depth * sampleSize
        let buffer = device.makeBuffer(length: length, options: .storageModeShared)!

        let commandQueue = device.makeCommandQueue()!
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeBlitCommandEncoder()!
        commandEncoder.copy(from: self, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin.zero, sourceSize: MTLSize(width, height, depth), to: buffer, destinationOffset: 0, destinationBytesPerRow: bytesPerRow, destinationBytesPerImage: bytesPerImage)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // MARK: -

        //    let data = Data(bytes: buffer.contents(), count: length)

        let b = BitmapDefinition(width: width, height: height * depth, pixelFormat: PixelFormat(mtlPixelFormat: pixelFormat))

        let d = UnsafeMutableRawBufferPointer(start: buffer.contents(), count: buffer.length)
        let context = CGContext.bitmapContext(data: d, definition: b)!
        let image = context.makeImage()!

        return image
    }

    @available(*, deprecated, message: "TODO: Merge all CGImage functions")
    var betterBetterCGImage: CGImage {
        let colorspace = CGColorSpaceCreateDeviceRGB()
        var data = Data(count: width * 4 * height)
        return data.withUnsafeMutableBytes { buffer in
            getBytes(buffer.baseAddress!, bytesPerRow: width * 4, from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)), mipmapLevel: 0)
            let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            let context = CGContext(data: buffer.baseAddress!, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorspace, bitmapInfo: bitmapInfo)!
            return context.makeImage()!
        }
    }
}

public extension Data {
    func toArray<T>(of: T.Type) -> [T] {
        withUnsafeBytes { buffer in
            let buffer = buffer.bindMemory(to: T.self)
            return Array(buffer)
        }
    }
}
