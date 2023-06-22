import Everything
import Shaders
import RenderKit

extension CommonBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .verticesBuffer:
            return .buffer
        case .frameStateBuffer:
            return .buffer
        case .transformsBuffer:
            return .buffer
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}

extension ParticleShadersBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .environmentBuffer:
            return .buffer
        case .particlesBuffer:
            return .buffer
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}

// MARK: -

extension GPULifeKernelBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .inputTexture:
            return .texture
        case .outputTexture:
            return .texture
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}

extension BlinnPhongBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .lightingModelArgumentBuffer:
            return .argumentBuffer
        case .materialArgumentBuffer:
            return .argumentBuffer
        case .blinnPhongModeConstant:
            return .constant
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}

extension UnlitShaderBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .baseColorTexture:
            return .texture
        case .baseColorSampler:
            return .sampler
        case .offsetsBuffer:
            return .buffer
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}

extension VoxelsBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .voxelsBuffer:
            return .buffer
        case .colorPaletteTexture:
            return .texture
        case .outputTexture:
            return .texture
        case .voxelSizeBuffer:
            return .buffer
        case .verticesBuffer:
            return .buffer
        case .indicesBuffer:
            return .buffer
        case .blinnPhongLightingModelArgumentBuffer:
            return .argumentBuffer
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}

extension DebugShaderBindings: ShaderIndex {
    public var kind: ShaderBinding.Kind {
        switch self {
        case .modeBuffer:
            return .buffer
        @unknown default:
            fatalError("Unexpected case")
        }
    }
}
