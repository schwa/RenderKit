import Everything
import MetalKit
import ModelIO
import simd
import SwiftUI

open class SphereSubrenderer: ShaderLibraryBasedSubrenderer {
    var mtkMesh: MTKMesh!

    var time: Double

    var diffuseTexture: MTLTexture!
    var ambientTexture: MTLTexture!
    var specularTexture: MTLTexture!

    public init(renderer: Renderer) throws {
        let mtlLibrary = try renderer.device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)
        let shaderLibrary = ShaderLibrary(mtlLibrary: mtlLibrary)

        shaderLibrary.types += [
            try StructureDefinition(key: "Vertex", attributes: [
                .init(name: "position", kind: .packed_float3),
                .init(name: "normal", kind: .packed_float3),
                .init(name: "textureCoordinate", kind: .packed_float2),
            ]),
            try StructureDefinition(key: "Uniforms", attributes: [
                .init(name: "modelViewProjectionTransform", kind: .float4x4),
                .init(name: "modelViewTransform", kind: .float4x4),
                .init(name: "normalTransform", kind: .float3x3),
            ]),
        ]
        shaderLibrary.shaders += [
            .init(name: "SphereVertexShader", type: .vertex, parameters: [
                .init(name: "vertices", index: .init(rawValue: 0), typeName: "Vertex", kind: .vertices),
                .init(name: "uniforms", index: .init(rawValue: 1), typeName: "Uniforms", kind: .uniform),
            ]),
            .init(name: "SphereFragmentShader", type: .fragment, parameters: [
                .init(name: "uniforms", index: .init(rawValue: 0), typeName: "Uniforms", kind: .uniform),
                .init(name: "diffuse", index: .init(rawValue: 2), typeName: nil, kind: .texture),
                .init(name: "ambient", index: .init(rawValue: 3), typeName: nil, kind: .texture),
                .init(name: "specular", index: .init(rawValue: 4), typeName: nil, kind: .texture),
            ]),
        ]

        time = CFAbsoluteTimeGetCurrent()
        try super.init(device: renderer.device, shaderLibrary: shaderLibrary)
    }

    override open func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        try shaderLibrary.configure(renderPipelineDescriptor: renderPipelineDescriptor, vertexShader: vertexShader, fragmentShader: fragmentShader)

        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        let allocator = MTKMeshBufferAllocator(device: renderer.device)
        let mesh = MDLMesh.newEllipsoid(withRadii: [50, 50, 50], radialSegments: 96, verticalSegments: 96, geometryType: .triangles, inwardNormals: false, hemisphere: false, allocator: allocator)
        print(mesh.vertexDescriptor)
        mesh.flipTextureCoordinates(inAttributeNamed: "textureCoordinate")
        mtkMesh = try MTKMesh(mesh: mesh, device: renderer.device)

        let loader = MTKTextureLoader(device: renderer.device)
        diffuseTexture = try loader.newTexture(name: "earth_diffuse", scaleFactor: 1, bundle: nil, options: nil)
        ambientTexture = try loader.newTexture(name: "earth_ambient", scaleFactor: 1, bundle: nil, options: nil)
        specularTexture = try loader.newTexture(name: "earth_specular", scaleFactor: 1, bundle: nil, options: nil)
        return renderPipelineDescriptor
    }

    override open func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        let delta = CFAbsoluteTimeGetCurrent() - time

        let rotation = simd_quatf(angle: Float(degreesToRadians(delta)) * 0, axis: [1, 0, 0])

        let d = MTLDepthStencilDescriptor()
        d.depthCompareFunction = .less
        d.isDepthWriteEnabled = true
        let depthStencilState = renderer.device.makeDepthStencilState(descriptor: d)

        commandEncoder.setDepthStencilState(depthStencilState)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)

        let uniformsType = shaderLibrary.types[vertexShader.uniforms.typeName!]!

        let aspect = Float(renderer.viewport.width) / Float(renderer.viewport.height)
        let fov: Float = (2.0 * .pi) / 5.0
        let near: Float = 1.0
        let far: Float = 400

        let modelTransform = simd_float4x4(rotation)
        let viewTransform = simd_float4x4(translate: [0, 0, -100])
        let projectionTransform = simd_float4x4.perspective(aspect: aspect, fovy: fov, near: near, far: far)

        let modelViewTransform = modelTransform * viewTransform

        let modelViewProjectionTransform = modelViewTransform * projectionTransform

        var uniforms = Accessor<[UInt8], DynamicRow>(layout: uniformsType.metalLayout, count: 1)
        // uniforms.worldTransform = simd_float3x4.scale(x: 1 / (Float(renderer.viewPort.width) * 0.5), y: 1 / (Float(renderer.viewPort.height) * 0.5), z: 1)
        uniforms[0].modelViewProjectionTransform = modelViewProjectionTransform
        uniforms[0].modelViewTransform = modelViewTransform
        uniforms[0].normalTransform = simd_float3x3(truncating: modelViewTransform)

        commandEncoder.setVertexBytes(uniforms.storage, index: vertexShader.uniforms.index.rawValue)

        let vertexBuffer = mtkMesh.vertexBuffers[0].buffer
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: vertexShader.vertices.index.rawValue)

        commandEncoder.setFragmentBytes(uniforms.storage, index: fragmentShader.uniforms.index.rawValue)

        commandEncoder.setFragmentTexture(diffuseTexture, index: fragmentShader.diffuse.index)
        commandEncoder.setFragmentTexture(ambientTexture, index: fragmentShader.ambient.index)
        commandEncoder.setFragmentTexture(specularTexture, index: fragmentShader.specular.index)

        for submesh in mtkMesh.submeshes {
            commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
        }
    }
}
