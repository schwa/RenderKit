import CoreGraphics
import Foundation
import Metal
import RenderKitSupport

public struct RenderState {
    public var device: MTLDevice
    public var graph: any RenderGraphProtocol
    public var targetTextureSize: CGSize = .zero
    public var cachedDepthTexture: MTLTexture?
    public var cachedLibrary: MTLLibrary?
    public var cachedComputePipelineStates: [AnyHashable: MTLComputePipelineState] = [:]
    public var cachedRenderPipelineStates: [AnyHashable: MTLRenderPipelineState] = [:]
    public var cachedDepthStencilStates: [DepthStencil: MTLDepthStencilState] = [:]
    public var cachedFunctionsByStage: [AnyHashable: MTLFunction] = [:]
    public var cachedArgumentEncodersForStage: [Pair<AnyHashable, ShaderBinding>: MTLArgumentEncoder] = [:]

    internal var setup = false {
        didSet {
            if setup == false {
                // TODO: throwing away all state is a _bad_ idea. We need to break state up into state that is discarded when the drawable changes and state that is persistent across drawable changes.
                cachedDepthTexture = nil
                cachedLibrary = nil
                cachedComputePipelineStates = [:]
                cachedRenderPipelineStates = [:]
                cachedDepthStencilStates = [:]
                cachedFunctionsByStage = [:]
                cachedArgumentEncodersForStage = [:]
            }
        }
    }

    internal init(device: MTLDevice, graph: some RenderGraphProtocol) {
        self.device = device
        self.graph = graph
    }
}

// MARK: -

public extension RenderState {
    func stages(forParameterKey key: RenderEnvironment.Key) -> [any StageProtocol] {
        let allStages = graph.passes.flatMap(\.stages)
        // NOTE: Cache
        return allStages.filter { stage in
            !stage.parameter(forKey: key).isEmpty
        }
    }

    mutating func argumentEncoder(stage: some StageProtocol, parameter: Parameter) throws -> MTLArgumentEncoder {
        if let argumentEncoder = cachedArgumentEncodersForStage[.init(stage.id, parameter.binding)] {
            return argumentEncoder
        }
        guard let cachedFunction = cachedFunctionsByStage[stage.id] else {
            fatalError("No cached function found for key: \(stage.id) (keys available: \(cachedFunctionsByStage.keys))")
        }
        let argumentEncoder = cachedFunction.makeArgumentEncoder(bufferIndex: try parameter.binding.argumentBufferIndex)
        argumentEncoder.label = "\(stage.id) Argument Encoder"
        cachedArgumentEncodersForStage[.init(stage.id, parameter.binding)] = argumentEncoder
        return argumentEncoder
    }

    mutating func argumentEncoder(forParameterKey key: RenderEnvironment.Key) throws -> MTLArgumentEncoder {
        let stage = stages(forParameterKey: key)[0]
        let parameter = stage.parameter(forKey: key)[0]
        return try argumentEncoder(stage: stage, parameter: parameter)
    }
}
