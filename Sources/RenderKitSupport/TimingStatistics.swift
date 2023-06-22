import Combine
import SwiftUI

public struct TimingStatistics {
    public let rate: SmoothedValue<Double>
    public let time: TimeInterval
    public let totalTime: TimeInterval
    public let count: Int
}

public struct TimingStatisticsPublisherKey: EnvironmentKey {
    public static var defaultValue = TimingStatisticsPublisher()
}

public extension EnvironmentValues {
    var timingStatisticsPublisher: TimingStatisticsPublisher {
        get {
            self[TimingStatisticsPublisherKey.self]
        }
        set {
            self[TimingStatisticsPublisherKey.self] = newValue
        }
    }
}

public class TimingStatisticsPublisher: Publisher {
    public typealias Output = TimingStatistics
    public typealias Failure = Never

    private var passthrough = PassthroughSubject<TimingStatistics, Never>()

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        passthrough.receive(subscriber: subscriber)
    }

    var startTime: CFAbsoluteTime?
    var lastTime: CFAbsoluteTime?
    var rate = SmoothedValue<Double>(smoothing: 0.95)
    var count: Int = 0
    var smoothedRate: Double?
    var smoothing: Double = 0.95

    public func tick() {
        let now = CFAbsoluteTimeGetCurrent()
        count += 1
        if startTime == nil {
            startTime = now
        }
        defer {
            self.lastTime = now
        }
        guard let lastTime else {
            return
        }

        let delta = now - lastTime
        let newFramerate = 1 / delta

        passthrough.send(TimingStatistics(rate: rate.update(current: newFramerate), time: delta, totalTime: now - startTime!, count: count))
    }
}

// MARK: -

public struct SmoothedValue<T> where T: BinaryFloatingPoint {
    let smoothing: T
    public private(set) var current: T?
    var previousSmoothed: T?
    public private(set) var smoothed: T?

    public init(smoothing: T = T(0.95)) {
        self.smoothing = smoothing
    }

    @discardableResult
    public mutating func update(current: T) -> Self {
        self.current = current
        if let previousSmoothed {
            self.previousSmoothed = smoothed
            smoothed = previousSmoothed * smoothing + (T(1.0) - smoothing) * current
        }
        else {
            previousSmoothed = current
        }
        return self
    }
}
