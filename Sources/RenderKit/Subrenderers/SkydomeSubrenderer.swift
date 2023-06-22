import Everything
import Foundation
import MetalKit
import ModelIO
import RenderKitShaders
import simd
import SwiftUI

public class SkydomeSubrenderer: Subrenderer {
    public var mtkMesh: MTKMesh!
    public var baseTexture: MTLTexture!
    public var parameters: CameraParametersProtocol
    public var url: URL!
    public var renderer: Renderer

    public init(renderer: Renderer, parameters: CameraParametersProtocol) throws {
        self.renderer = renderer
        self.parameters = parameters
    }

    public func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let mtlLibrary = try renderer.device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let vertexFunction = mtlLibrary.makeFunction(name: "SkydomeVertexShader")
        renderPipelineDescriptor.vertexFunction = vertexFunction

        var builder = VertexDescriptorBuilder()
        builder.addAttribute(format: .float3, size: 12) // size of packed float3
        builder.addAttribute(format: .float3, size: 12) // size of packed float3
        builder.addAttribute(format: .float2, size: 8) // size of packed float2
        renderPipelineDescriptor.vertexDescriptor = builder.vertexDescriptor

        let fragmentFunction = mtlLibrary.makeFunction(name: "SkydomeFragmentShader")
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        let allocator = MTKMeshBufferAllocator(device: renderer.device)
        let radius: Float = 200
        let radialSegments = 32
        let verticalSegments = 32
        let mesh = MDLMesh.newEllipsoid(withRadii: [radius, radius, radius], radialSegments: radialSegments, verticalSegments: verticalSegments, geometryType: .triangles, inwardNormals: false, hemisphere: false, allocator: allocator)
        mtkMesh = try MTKMesh(mesh: mesh, device: renderer.device)

        let loader = MTKTextureLoader(device: renderer.device)

        baseTexture = try loader.newTexture(URL: url, options: nil)
        return renderPipelineDescriptor
    }

    public func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        // let rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        let aspect = Float(renderer.viewport.width) / Float(renderer.viewport.height)
        let modelTransform = simd_float4x4.identity
        let viewTransform = simd_float4x4(simd_quatf(angle: parameters.yaw, axis: [0, 1, 0]) * simd_quatf(angle: parameters.pitch, axis: [1, 0, 0]))
        let projectionTransform = parameters.projectionTransform(aspect: aspect)

        let modelViewTransform = modelTransform * viewTransform

        let modelViewProjectionTransform = modelViewTransform * projectionTransform

        var uniforms = UniformsX()
        uniforms.modelViewProjectionTransform = modelViewProjectionTransform
        uniforms.modelViewTransform = modelViewTransform

        commandEncoder.setVertexValue(&uniforms, index: Int(SkydomeVertexShader_Uniforms))

        let vertexBuffer = mtkMesh.vertexBuffers[0].buffer
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(SkydomeVertexShader_Vertices))
        commandEncoder.setFragmentValue(&uniforms, index: Int(SkydomeFragmentShader_Uniforms))
        commandEncoder.setFragmentTexture(baseTexture, index: Int(SkydomeFramgentShader_BaseTexture))
        commandEncoder.setTriangleFillMode(.fill)

        for submesh in mtkMesh.submeshes {
            commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
        }
    }
}
