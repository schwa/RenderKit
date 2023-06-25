import Foundation
import RenderKit
import Metal
import Shaders

public struct BlinnPhongRenderPass: RenderPipelineProtocol {
    public let id = String(describing: Self.self)
    public struct VertexStage: VertexStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("BlinnPhongVertexShader")
        public let parameters: [Parameter] = [
            .init(index: CommonBindings.verticesBuffer, variable: "$VERTICES"),
            .init(index: CommonBindings.transformsBuffer, variable: "$TRANSFORMS"),
        ]
    }

    public struct FragmentStage: FragmentStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("BlinnPhongFragmentShader")
        public let parameters: [Parameter] = [
            .init(index: BlinnPhongBindings.lightingModelArgumentBuffer, variable: "$LIGHTING"),
            .init(index: BlinnPhongBindings.materialArgumentBuffer, variable: "$BLINN_PHONG_MATERIAL"),
        ]
        public let functionConstants: [FunctionConstant] = [
            FunctionConstant(index: BlinnPhongBindings.blinnPhongModeConstant, value: 0),
        ]
    }

    public let vertexStage = VertexStage()
    public let fragmentStage = FragmentStage()
    public let configuration: RenderPassOptions? = RenderPassOptions.default.modifiedForFirstPass()
    public let selectors: Set<PipelineSelector> = ["teapot"]

    public init() {
    }
}
