import Foundation
import Metal

class StopWatch: CustomStringConvertible {
    var last: CFAbsoluteTime?

    var time: CFAbsoluteTime {
        let now = CFAbsoluteTimeGetCurrent()
        if last == nil {
            last = now
        }
        return now - last!
    }

    var description: String {
        return "\(time)"
    }
}

func time(_ block: () -> Void) -> CFAbsoluteTime {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let end = CFAbsoluteTimeGetCurrent()
    return end - start
}

public func nextPowerOfTwo(_ value: Double) -> Double {
    let logValue = log2(Double(value))
    let nextPower = pow(2.0, ceil(logValue))
    return nextPower
}

public func nextPowerOfTwo(_ value: Int) -> Int {
    return Int(nextPowerOfTwo(Double(value)))
}

extension Collection where Element: Comparable {
    var isSorted: Bool {
        return zip(self, sorted()).allSatisfy { lhs, rhs in
            lhs == rhs
        }
    }
}

public extension MTLSize {
    init(width: Int) {
        self = MTLSize(width: width, height: 1, depth: 1)
    }
}
