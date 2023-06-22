import Foundation
import simd

public struct Attribute {
    public let name: String
    public let kind: MetalType // TODO: Rename

    public init(name: String, kind: MetalType) {
        self.name = name
        self.kind = kind
    }
}
