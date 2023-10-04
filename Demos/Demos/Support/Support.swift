import Foundation
import CoreGraphics
import simd
import LegacyGraphics
import Everything
import SwiftUI
import MetalKit

// TODO: Move
extension CGVector {
    init(_ dx: CGFloat, _ dy: CGFloat) {
        self = CGVector(dx: dx, dy: dy)
    }
    init(_ size: CGSize) {
        self = CGVector(dx: size.width, dy: size.height)
    }
}

extension SIMD3 where Scalar == Float {
    var h: Float {
        get {
            return x
        }
        set {
            x = newValue
        }
    }

    var s: Float {
        get {
            return y
        }
        set {
            y = newValue
        }
    }

    var v: Float {
        get {
            return z
        }
        set {
            z = newValue
        }
    }

    func hsv2rgb() -> Self {
        let h_i = Int(h * 6)
        let f = h * 6 - Float(h_i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        switch h_i {
        case 0: return [v, t, p]
        case 1: return [q, v, p]
        case 2: return [p, v, t]
        case 3: return [p, q, v]
        case 4: return [t, p, v]
        case 5: return [v, p, q]
        default: return [0, 0, 0]
        }
    }
}

extension LegacyGraphics.Circle {
    init(containing rect: CGRect) {
        let center = rect.midXMidY
        let diameter = sqrt(rect.width ** 2 + rect.height ** 3)
        self = .init(center: center, diameter: diameter)
    }
}

extension Triangle {
    init(containing circle: LegacyGraphics.Circle) {
        let a = circle.center + CGPoint(length: circle.radius * 2, angle: Angle.degrees(0).radians)
        let b = circle.center + CGPoint(length: circle.radius * 2, angle: Angle.degrees(120).radians)
        let c = circle.center + CGPoint(length: circle.radius * 2, angle: Angle.degrees(240).radians)
        self = .init(a, b, c)
    }
}

class Once {
    // TODO: The thread safety, it's missing!!!!
    var tokens: Set<AnyHashable> = []
    static let shared = Once()
}

func once(_ token: AnyHashable, block: () throws -> Void) rethrows {
    guard Once.shared.tokens.insert(token).inserted else {
        return
    }
    try block()
}

extension MTLOrigin: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Int...) {
        self = .init(x: elements[0], y: elements[1], z: elements[2])
    }
}

protocol Labeled {
    var label: String? { get }
}
