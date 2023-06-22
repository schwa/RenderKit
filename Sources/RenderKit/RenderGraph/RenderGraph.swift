import Everything
import Metal

class RenderGraphSubrenderer: Subrenderer {
    func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        unimplemented()
    }

    func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        unimplemented()
    }
}

// https://github.com/acdemiralp/fg
// https://docs.unrealengine.com/en-US/Programming/Rendering/RenderDependencyGraph/index.html
// https://ourmachinery.com/post/high-level-rendering-using-render-graphs/
// https://themaister.net/blog/2017/08/15/render-graphs-and-vulkan-a-deep-dive/
// https://www.ea.com/frostbite/news/framegraph-extensible-rendering-architecture-in-frostbite

enum RenderGraph {
    class Node {
    }
}
