import Everything
import Foundation
import MetalKit
import os
import SwiftUI
import MetalSupportUnsafeConformances
import simd
import Metal
import ModelIO
import MetalPerformanceShaders
import SIMDSupport
import CoreGraphicsSupport
import SwiftFormats

public enum RenderKitError: Error {
    case generic(String)
}

extension CGSize {
    static func / (lhs: CGFloat, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs / rhs.width, height: lhs / rhs.height)
    }
}

// MARK: -
