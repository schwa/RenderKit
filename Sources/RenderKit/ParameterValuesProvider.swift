import Metal
import MetalSupport
import RenderKitSupport

public enum ParameterValue {
    // All the MTL types here are effectively readonly. Making them sendable.

    case buffer(MTLBuffer, offset: Int)
    case texture(MTLTexture)
    case samplerState(MTLSamplerState)
    case accessor(UnsafeBytesAccessor)
    case argumentBuffer(MTLBuffer, [MTLResourceUsage: [MTLResource]])
}

extension MTLRenderCommandEncoder {
    func setParameterValue(_ value: ParameterValue, stage: MTLRenderStages, binding: ShaderBinding) throws {
        switch value {
        case .buffer(let buffer, let offset):
            setBuffer(buffer, offset: offset, stage: stage, index: try binding.bufferIndex)
        case .texture(let texture):
            setTexture(texture, stage: stage, index: try binding.textureIndex)
        case .samplerState(let samplerState):
            setSamplerState(samplerState, stage: stage, index: try binding.samplerIndex)
        case .accessor(let accessor):
            let index = try binding.bufferIndex
            accessor.withUnsafeBytes { bytes in
                setBytes(bytes, stage: stage, index: index)
            }
        case .argumentBuffer(let buffer, let resources):
            setBuffer(buffer, offset: 0, stage: stage, index: try binding.argumentBufferIndex)
            for (usage, resources) in resources {
                // TODO: stages my be over kill - but if not create an allCases (old useResources deprecated)
                useResources(resources, usage: usage, stages: [.fragment, .mesh, .tile, .vertex, .object])
            }
        }
    }
}

extension MTLComputeCommandEncoder {
    func setParameterValue(_ value: ParameterValue, binding: ShaderBinding) throws {
        switch value {
        case .buffer(let buffer, let offset):
            try setBuffer(buffer, offset: offset, index: binding.bufferIndex)
        case .texture(let texture):
            try setTexture(texture, index: binding.textureIndex)
        case .samplerState(let samplerState):
            try setSamplerState(samplerState, index: binding.samplerIndex)
        case .accessor(let accessor):
            let index = try binding.bufferIndex
            accessor.withUnsafeBytes { bytes in
                setBytes(bytes.baseAddress!, length: bytes.count, index: index)
            }
        case .argumentBuffer(let buffer, let resources):
            try setBuffer(buffer, offset: 0, index: binding.bufferIndex)
            for (usage, resources) in resources {
                useResources(resources, usage: usage)
            }
        }
    }
}
