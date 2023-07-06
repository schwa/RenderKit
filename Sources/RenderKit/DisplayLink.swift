#if os(macOS)
import AppKit
#else
import UIKit
#endif

// TODO: Downsides: Only one AsyncStream can be consumed at once. Each new events() creates a new AsyncStream.
public struct DisplayLink2 {
    private class Helper: NSObject {
        var callback: (() -> Void)? = nil
        @objc func callCallback() {
            callback?()
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

    internal init(runloop: RunLoop = .current, mode: RunLoop.Mode = .default) {
        self.runloop = runloop
        self.mode = mode

        self.helper = Helper()
        self.displayLink = NSScreen.screens[0].displayLink(target: helper, selector: #selector(Helper.callCallback))
    }

    public func events() -> AsyncStream<(CFTimeInterval, CFTimeInterval)> {
        return AsyncStream { continuation in
            helper.callback = {
                continuation.yield((displayLink.timestamp, displayLink.duration))
            }
            continuation.onTermination = { @Sendable _ in
                displayLink.invalidate()
            }
            displayLink.add(to: .current, forMode: .default)
        }
    }
}


func test() async {

    let displayLink = DisplayLink2()
    for await event in displayLink.events() {
        print(event)
    }

}
