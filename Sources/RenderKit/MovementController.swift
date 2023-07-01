#if os(macOS)
    @preconcurrency import Combine
    import Everything
    import Foundation
    @preconcurrency import GameController
    import simd

    import AppKit
    public class CapturedMouseStream: AsyncSequence {
        public typealias Element = CGPoint

        private let stream: AsyncStream<CGPoint>

        public init(hideMouse: Bool = false) {
            stream = AsyncStream<Element> { continuation in
                if hideMouse {
                    CGDisplayHideCursor(CGMainDisplayID())
                    CGAssociateMouseAndMouseCursorPosition(0)
                    CGDisplayMoveCursorToPoint(CGMainDisplayID(), [0, 0])
                }
                let monitor = NSEvent.addLocalMonitorForEventsEx(matching: [.mouseMoved, .leftMouseDragged]) { event in
                    let delta = CGGetLastMouseDelta()
                    continuation.yield(CGPoint(x: CGFloat(delta.x), y: CGFloat(delta.y)))
                    return event
                }
                continuation.onTermination = { @Sendable _ in
                    if hideMouse {
                        CGDisplayShowCursor(CGMainDisplayID())
                        CGAssociateMouseAndMouseCursorPosition(1)
                    }
                    monitor?.cancel()
                }
            }
        }

        public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
            stream.makeAsyncIterator()
        }
    }

    // NOTE: Move.
    extension NSEvent {
        final class EventMonitor: @unchecked Sendable {
            private let monitor: Any

            init(_ monitor: Any) {
                self.monitor = monitor
            }

            func cancel() {
                NSEvent.removeMonitor(monitor)
            }
        }

        static func addLocalMonitorForEventsEx(matching mask: NSEvent.EventTypeMask, handler block: @escaping (NSEvent) -> NSEvent?) -> EventMonitor? {
            addLocalMonitorForEvents(matching: mask, handler: block).map { EventMonitor($0) }
        }
    }

    extension GCExtendedGamepad {
        enum Event {
            case elementChanged(GCExtendedGamepad, GCDeviceElement)
        }

        var events: AsyncStream<Event> {
            AsyncStream<Event> { continuation in
                valueChangedHandler = { _, element in
                    continuation.yield(.elementChanged(self, element))
                }
                continuation.onTermination = { @Sendable [weak self] _ in
                    self?.valueChangedHandler = nil
                }
            }
        }
    }

    public actor KeyboardStream: AsyncSequence {
        public typealias Element = Set<VirtualKeyCode>

        let monitoredKeys: Set<VirtualKeyCode>

        public init(monitoredKeys: Set<VirtualKeyCode>) {
            self.monitoredKeys = monitoredKeys
        }

        public nonisolated func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
            let monitoredKeys = monitoredKeys
            var keysDown: Set<VirtualKeyCode> = []
            let stream = AsyncStream<Element> { continuation in
                let monitor = NSEvent.addLocalMonitorForEventsEx(matching: [.keyUp, .keyDown]) { event in
                    guard let key = VirtualKeyCode(rawValue: event.keyCode), monitoredKeys.contains(key) else {
                        return event
                    }
                    switch event.type {
                    case .keyUp:
                        keysDown.remove(key)
                    case .keyDown:
                        keysDown.insert(key)
                    default:
                        fatalError("Should not be here.")
                    }
                    continuation.yield(keysDown)
                    return nil
                }
                continuation.onTermination = { @Sendable _ in
                    monitor?.cancel()
                }
            }
            return stream.makeAsyncIterator()
        }
    }

    // MARK: -

    public final actor WASDStream: AsyncSequence, Sendable {
        public typealias Element = CGPoint

        private let displayLinkPublisher: DisplayLinkPublisher

        private var currentKeys: Set<VirtualKeyCode> = []

        public init(displayLinkPublisher: DisplayLinkPublisher) {
            self.displayLinkPublisher = displayLinkPublisher
        }

        private func update(keys: Set<VirtualKeyCode>) async {
            currentKeys = keys
        }

        private func delta(for keys: Set<VirtualKeyCode>) -> CGPoint {
            var delta = CGPoint.zero
            if keys.contains(.ANSI_W) {
                delta += [0, -1]
            }
            if keys.contains(.ANSI_S) {
                delta += [0, 1]
            }
            if keys.contains(.ANSI_A) {
                delta += [-1, 0]
            }
            if keys.contains(.ANSI_D) {
                delta += [1, 0]
            }
            return delta
        }

        public nonisolated func makeAsyncIterator() -> AsyncStream<CGPoint>.Iterator {
            let stream = AsyncStream<CGPoint> { continuation in
                let cancellable = displayLinkPublisher.sink { [weak self] _ in
                    guard let strong_self = self else {
                        return
                    }
                    Task {
                        _ = await continuation.yield(strong_self.delta(for: strong_self.currentKeys))
                    }
                }

                let keyboardStream = KeyboardStream(monitoredKeys: [.ANSI_W, .ANSI_S, .ANSI_A, .ANSI_D])
                let keyboardTask = Task {
                    for await keys in keyboardStream {
                        await update(keys: keys)
                        await continuation.yield(delta(for: currentKeys))
                    }
                }

                continuation.onTermination = { @Sendable _ in
                    cancellable.cancel()
                    keyboardTask.cancel()
                }
            }
            return stream.makeAsyncIterator()
        }
    }
#endif
