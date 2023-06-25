import Everything
import MetalKit
import Shaders
import simd
import RenderKit
import RenderKitSupport

public class SceneGraphRenderSubmitter: RenderSubmitter {
    let graph: SceneGraph

    public init(scene: SceneGraph) {
        graph = scene
    }

    func entities(for pass: some RenderPassProtocol) -> [ModelEntity] {
        graph.entities
            .filter { !$0.isHidden }
            .filter { !$0.selectors.isDisjoint(with: pass.selectors) }
//            .filter {
//                pass.name == "Phong Shader" && $0.materials.contains(where: { ($0 as? BlinnPhongMaterial) != nil })
//                || pass.name == "Unlit" && $0.materials.contains(where: { ($0 as? UnlitMaterial) != nil })
//            }
    }

    public func shouldSubmit(pass: some RenderPassProtocol, environment: RenderEnvironment) -> Bool {
        !entities(for: pass).isEmpty
    }

    public func setup(state: inout RenderState) throws {
    }

    public func prepareRender(pass: some RenderPassProtocol, state: inout RenderState, environment: inout RenderEnvironment) throws {
        // NOTE: We are doing this every frame. We can instead keep track of _ALL_ materials in a scene and do it only when that changes.

        for entity in graph.entities {
            for index in entity.materials.indices {
                try entity.materials[index].setup(state: &state)
            }
        }
        try graph.lightingModel.setup(state: &state)
        environment.update(try graph.lightingModel.parameterValues())
    }

    public func submit(pass: some RenderPassProtocol, state: RenderState, environment: inout RenderEnvironment, commandEncoder: MTLRenderCommandEncoder) throws {
        let drawableSize = state.targetTextureSize
        let aspectRatio = Float(drawableSize.width / drawableSize.height)
        let projectionTransform = graph.camera.projection._matrix(aspectRatio: aspectRatio)
        let viewTransform = graph.camera.transform.matrix.inverse

        var modelStack: [simd_float4x4] = []

        func visit(node: Node) throws {
            let modelTransform = node.transform.matrix * (modelStack.last ?? .identity)
            modelStack.append(modelTransform)
            defer {
                _ = modelStack.popLast()
            }

            for child in node.children ?? [] {
                try visit(node: child)
            }

            guard let entity = node as? ModelEntity else {
                return
            }

            guard !entity.isHidden && !entity.selectors.isDisjoint(with: pass.selectors) else {
                return
            }

            var transforms = Transforms()
            transforms.modelView = viewTransform * modelTransform
            transforms.modelNormal = simd_float3x3(truncating: modelTransform).transpose.inverse
            transforms.projection = projectionTransform

            environment["$VERTICES"] = .buffer(entity.geometry.mesh.vertexBuffers[0].buffer, offset: entity.geometry.mesh.vertexBuffers[0].offset)
            environment["$TRANSFORMS"] = .accessor(UnsafeBytesAccessor(transforms))

            for material in entity.materials {
                environment.update(try material.parameterValues())
            }

            // NOTE: We keep setting lighting (which is the same) for every entity)
            try commandEncoder.set(environment: environment, forPass: pass)
            commandEncoder.draw(geometry: entity.geometry)
        }
        try visit(node: graph.scene)
    }
}
