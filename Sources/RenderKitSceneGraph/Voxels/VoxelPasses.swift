import Foundation
import RenderKit
import Shaders

public struct VoxelRenderPass: RenderPassProtocol {
    public let id = String(describing: Self.self)
    public struct VertexStage: VertexStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("VoxelVertexShader")
        public let parameters: [Parameter] = [
            .init(index: CommonBindings.verticesBuffer, variable: "$VERTICES"),
            .init(index: CommonBindings.transformsBuffer, variable: "$TRANSFORMS"),
            .init(index: VoxelsBindings.colorPaletteTexture, variable: "$VOXEL_COLOR_PALETTE"),
        ]
    }

    public struct FragmentStage: FragmentStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("VoxelFragmentShader")
        public let parameters: [Parameter] = [
            .init(index: BlinnPhongBindings.lightingModelArgumentBuffer, variable: "$LIGHTING"),
        ]
        public let functionConstants: [FunctionConstant] = [
            FunctionConstant(index: BlinnPhongBindings.blinnPhongModeConstant, value: 0),
        ]
    }

    public let vertexStage = VertexStage()
    public let fragmentStage = FragmentStage()
    public let selectors: Set<PassSelector> = ["voxel"]

    public init() {
    }
}
