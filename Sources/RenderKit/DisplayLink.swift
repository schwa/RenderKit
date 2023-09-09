#if os(macOS)
import AppKit
import QuartzCore
#else
import UIKit
#endif
import SwiftUI

@available(macOS 14, iOS 15, tvOS 16, *)
public class DisplayLink2 {

    public struct Event {
        public var timestamp: CFTimeInterval
        public var duration: CFTimeInterval
    }

    private class Helper: NSObject {
        var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

        deinit {
            continuations.values.forEach {
                $0.finish()
            }
        }

        @objc func callCallback(_ displayLink: CADisplayLink) {
            for continuation in continuations.values {
                continuation.yield(Event(timestamp: displayLink.timestamp, duration: displayLink.duration))
            }
        }
    }

    private let runloop: RunLoop
    private let mode: RunLoop.Mode
    private let helper: Helper
    private let displayLink: CADisplayLink

    public var isPaused: Bool {
        get {
            return displayLink.isPaused
        }
        set {
            displayLink.isPaused = newValue
        }
    }

    private init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, displayLinkFactory: (Helper) -> CADisplayLink) {
        self.runloop = runloop
        self.mode = mode
        self.helper = Helper()
        self.displayLink = displayLinkFactory(helper)
        displayLink.add(to: .current, forMode: .default)
    }

    deinit {
        self.displayLink.invalidate()
    }

    public convenience init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default) {
#if os(macOS)
        self.init(runloop: runloop, mode: mode, source: NSScreen.screens[0])
#else
        self.init(runloop: runloop, mode: mode) {
            CADisplayLink(target: $0, selector: #selector(Helper.callCallback))
        }
#endif
    }

    public func events() -> AsyncStream<Event> {
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        let id = UUID()
        helper.continuations[id] = continuation
        continuation.onTermination = { @Sendable [weak helper] _ in
            helper?.continuations[id] = nil
        }
        return stream
    }
}

#if os(macOS)
@available(macOS 14, iOS 15, tvOS 16, *)
public extension DisplayLink2 {
    convenience init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, source: NSScreen) {
        self.init(runloop: runloop, mode: mode) {
            source.displayLink(target: $0, selector: #selector(Helper.callCallback))
        }
    }
    convenience init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, source: NSWindow) {
        self.init(runloop: runloop, mode: mode) {
            source.displayLink(target: $0, selector: #selector(Helper.callCallback))
        }
    }
    convenience init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, source: NSView) {
        self.init(runloop: runloop, mode: mode) {
            source.displayLink(target: $0, selector: #selector(Helper.callCallback))
        }
    }
}
#endif

@available(macOS 14, iOS 15, tvOS 16, *)
public struct DisplayLinkKey: EnvironmentKey {
    public static var defaultValue: DisplayLink2? = nil
}

@available(macOS 14, iOS 15, tvOS 16, *)
public extension EnvironmentValues {
    var displayLink: DisplayLink2? {
        get {
            self[DisplayLinkKey.self]
        }
        set {
            self[DisplayLinkKey.self] = newValue
        }
    }
}

@available(macOS 14, iOS 15, tvOS 16, *)
public extension View {
    func displayLink(_ displayLink: DisplayLink2) -> some View {
        environment(\.displayLink, displayLink)
    }
}
