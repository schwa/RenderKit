import Everything
import Metal

// TODO: needs to not be a class. This is mostly useuless. Can be replaced by helper functions?
open class ShaderLibraryBasedSubrenderer: Subrenderer {
    public let shaderLibrary: ShaderLibrary
    public let vertexShader: Shader
    public let fragmentShader: Shader

    public init(device: MTLDevice, shaderLibrary: ShaderLibrary) throws {
        self.shaderLibrary = shaderLibrary
        // TODO: This assumes one vertex and fragement shader per library.
        vertexShader = shaderLibrary.shaders.first { $0.type == .vertex }!
        fragmentShader = shaderLibrary.shaders.first { $0.type == .fragment }!
    }

    open func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        try shaderLibrary.configure(renderPipelineDescriptor: renderPipelineDescriptor, vertexShader: vertexShader, fragmentShader: fragmentShader)
        return renderPipelineDescriptor
    }

    open func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        unimplemented()
    }
}
