import Foundation
import RenderKit
import Metal
import Shaders

public struct LifeComputePass: ComputePipelineProtocol {
    public let id = String(describing: Self.self)
    public let workSize: MTLSize = [1024, 1024, 1]
    public struct ComputeStage: ComputeStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("gpuLifeKernelWrap")
        public let parameters: [Parameter] = [
            .init(index: GPULifeKernelBindings.inputTexture, variable: "$INPUT_TEXTURE", usage: .read),
            .init(index: GPULifeKernelBindings.outputTexture, variable: "$OUTPUT_TEXTURE", usage: .write),
        ]
    }

    public let computeStage = ComputeStage()

    public init() {
    }
}

public struct GameOfLifeRenderPass: RenderPipelineProtocol {
    public let id = String(describing: Self.self)
    public struct VertexStage: VertexStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("FlatVertexShader")
        public let parameters: [Parameter] = [
            .init(index: CommonBindings.verticesBuffer, variable: "$VERTICES"),
            .init(index: CommonBindings.transformsBuffer, variable: "$TRANSFORMS"),
            .init(index: UnlitShaderBindings.offsetsBuffer, constant: [0, 0, 0]),
        ]
    }

    public struct FragmentStage: FragmentStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("FlatFragmentShader_uint")
        public let parameters: [Parameter] = [
            .init(index: UnlitShaderBindings.baseColorTexture, variable: "$OUTPUT_TEXTURE"),
            .init(index: UnlitShaderBindings.baseColorSampler, variable: "$TEST_SAMPLER"),
        ]
    }

    public let vertexStage = VertexStage()
    public let fragmentStage = FragmentStage()
    public let selectors: Set<PipelineSelector> = ["plane"]

    public init() {
    }
}
