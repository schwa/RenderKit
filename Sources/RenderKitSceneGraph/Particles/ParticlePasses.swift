import Metal
import RenderKit
import RenderKitSupport
import Shaders

public struct ParticleUpdatePass: ComputePassProtocol {
    public let id = String(describing: Self.self)
    public let workSize: MTLSize = [10000, 1, 1]
    public struct ComputeStage: ComputeStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("particleUpdate")
        public let parameters: [Parameter] = [
            Parameter(index: ParticleShadersBindings.particlesBuffer, variable: "$PARTICLES"),
            Parameter(index: ParticleShadersBindings.environmentBuffer, variable: "$PARTICLES_ENVIRONMENT"),
        ]
    }

    public let computeStage = ComputeStage()

    public init() {
    }
}

public struct ParticleRenderPass: RenderPassProtocol {
    public let id = String(describing: Self.self)
    public struct VertexStage: VertexStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("particleVertexShader")
        public let parameters: [Parameter] = [
            .init(index: CommonBindings.verticesBuffer, variable: "$VERTICES"),
            .init(index: ParticleShadersBindings.particlesBuffer, variable: "$PARTICLES"),
            .init(index: CommonBindings.transformsBuffer, variable: "$TRANSFORMS"),
        ]
    }

    public struct FragmentStage: FragmentStageProtocol {
        public let id: AnyHashable = UUID()
        public let function = FunctionProvider.name("particleFragmentShader")
        public let parameters: [Parameter] = [
            .init(index: ParticleShadersBindings.particlesBuffer, variable: "$PARTICLES"),
        ]
    }

    public let vertexStage = VertexStage()
    public let fragmentStage = FragmentStage()
    public let selectors: Set<PassSelector> = ["particles"]

    public init() {
    }
}
