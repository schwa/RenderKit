import RenderKit
import Shaders

public struct DebugVisualizerPass: RenderPassProtocol {
    public let id = String(describing: Self.self)
    public struct VertexStage: VertexStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("DebugVisualizerVertexShader")
        public let parameters: [Parameter] = [
            .init(index: CommonBindings.verticesBuffer, variable: "$VERTICES"),
            .init(index: CommonBindings.transformsBuffer, variable: "$TRANSFORMS"),
            .init(index: UnlitShaderBindings.offsetsBuffer, constant: [0, 0, 0]),
        ]
    }

    public struct FragmentStage: FragmentStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("DebugVisualizerFragmentShader")
        public let parameters: [Parameter] = [
            .init(index: DebugShaderBindings.modeBuffer, variable: "$DEBUG_MODE"),
        ]
    }

    public let vertexStage = VertexStage()
    public let fragmentStage = FragmentStage()

    public init() {
    }
}

public struct WireframePass: RenderPassProtocol {
    public let id = String(describing: Self.self)
    public struct VertexStage: VertexStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("FlatVertexShader")
        public let parameters: [Parameter] = [
            .init(index: CommonBindings.verticesBuffer, variable: "$VERTICES"),
            .init(index: CommonBindings.transformsBuffer, variable: "$TRANSFORMS"),
            .init(index: UnlitShaderBindings.offsetsBuffer, constant: [0, 0, -0.001]),
        ]
    }

    public struct FragmentStage: FragmentStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("FlatFragmentShader")
        public let parameters: [Parameter] = [
            .init(index: UnlitShaderBindings.baseColorTexture, variable: "$TEST_TEXTURE"),
            .init(index: UnlitShaderBindings.baseColorSampler, variable: "$TEST_SAMPLER"),
        ]
    }

    public let vertexStage = VertexStage()
    public let fragmentStage = FragmentStage()
    public let selectors: Set<PassSelector> = ["teapot"]
    public let configuration: RenderPassOptions? = {
        var options = RenderPassOptions.default
        options.fillMode = .lines
        return options
    }()

    public init() {
    }
}
