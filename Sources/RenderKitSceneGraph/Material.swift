import Everything
import Metal
import MetalKit
import RenderKit

public protocol MaterialProtocol: ParameterValuesProvider {
}

// MARK: -

public struct UnlitMaterial: MaterialProtocol, Codable {
    public var baseColor: MaterialParameter

    public init(baseColor: SIMD4<Float>) throws {
        self.baseColor = try .init(color: baseColor, label: "baseColor")
    }
}

extension UnlitMaterial: ParameterValuesProvider {
    public mutating func setup(state: inout RenderState) throws {
//        unimplemented()
    }

    public func parameterValues() throws -> [RenderEnvironment.Key: ParameterValue] {
//        unimplemented()
        [:]
    }
}
