#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct DisplayLink2 {
    private class Helper: NSObject {
        let callback: () -> Void
        init(_ callback: @escaping () -> Void) {
            self.callback = callback
        }
        @objc func callCallback() {
            callback()
        }
    }

    private let runloop: RunLoop
    private let mode: RunLoop.Mode
    private let displayLinkFactory: (@escaping () -> Void) -> CADisplayLink

    internal init(runloop: RunLoop, mode: RunLoop.Mode, displayLinkFactory: @escaping (@escaping () -> Void) -> CADisplayLink) {
        self.runloop = runloop
        self.mode = mode
        self.displayLinkFactory = displayLinkFactory
    }

    public init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default) {
#if os(macOS)
        self = Self(runloop: runloop, mode: mode, source: NSScreen.screens[0])
#else
        self = Self(runloop: runloop, mode: mode) = { callback in
            let helper = Helper(callback)
            return CADisplayLink(target: helper, selector: #selector(Helper.callCallback))
        }
#endif
    }

    public func events() -> AsyncStream<()> {
        return AsyncStream { continuation in
            let displayLink = displayLinkFactory {
                continuation.yield(())
            }
            continuation.onTermination = { @Sendable _ in
                displayLink.invalidate()
            }
            displayLink.add(to: .current, forMode: .default)
        }
    }
}

extension DisplayLink2 {
    init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, source: NSScreen) {
        self = Self(runloop: runloop, mode: mode) { callback in
            let helper = Helper(callback)
            return source.displayLink(target: helper, selector: #selector(Helper.callCallback))
        }
    }

    init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, source: NSWindow) {
        self = Self(runloop: runloop, mode: mode) { callback in
            let helper = Helper(callback)
            return source.displayLink(target: helper, selector: #selector(Helper.callCallback))
        }
    }

    init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default, source: NSView) {
        self = Self(runloop: runloop, mode: mode) { callback in
            let helper = Helper(callback)
            return source.displayLink(target: helper, selector: #selector(Helper.callCallback))
        }
    }
}
