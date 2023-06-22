import Everything
import Foundation
import MetalKit
import ModelIO
import RenderKitShaders
import simd
import SwiftUI

public class SimpleWireframeSubrenderer: Subrenderer {
    public var mesh: MTKMesh?

    public var model: CameraParameters

    public init(renderer: Renderer, model: CameraParameters) throws {
        self.model = model
    }

    public func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.layouts[0].stride = 12
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor

        let mtlLibrary = try renderer.device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)

        let vertexFunction = mtlLibrary.makeFunction(name: "simpleWireframeVertexShader")
        renderPipelineDescriptor.vertexFunction = vertexFunction

        let fragmentFunction = mtlLibrary.makeFunction(name: "simpleWireframeFragmentShader")
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        return renderPipelineDescriptor
    }

    public func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        guard let mesh = mesh else {
            return
        }

        // TODO: Clean up duplicated code
        let aspect = Float(renderer.viewport.width) / Float(renderer.viewport.height)
        let modelTransform = simd_float4x4(simd_quatf(angle: model.yaw, axis: [0, 1, 0]) * simd_quatf(angle: model.pitch, axis: [1, 0, 0]))
        let viewTransform = simd_float4x4(translate: [0, 0, -175])
        let projectionTransform = model.projectionTransform(aspect: aspect)
        // let modelViewTransform = modelTransform * viewTransform
        // let modelViewProjectionTransform = modelViewTransform * projectionTransform

        var uniformsX = UniformsX()
        uniformsX.modelViewProjectionTransform = modelTransform * viewTransform * projectionTransform
        uniformsX.modelViewTransform = modelTransform * viewTransform
        uniformsX.normalTransform = simd_float4x4(simd_float3x3(truncating: modelTransform * viewTransform))
        commandEncoder.setVertexValue(&uniformsX, index: SimpleWireframeVertexShader.uniforms.rawValue)

        let vertexBuffer = mesh.vertexBuffers[0].buffer
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: SimpleWireframeVertexShader.vertices.rawValue)

        commandEncoder.setFragmentValue(&uniformsX, index: SimpleWireframeFragmentShader.uniforms.rawValue)

        commandEncoder.setFrontFacing(.clockwise)
        commandEncoder.setCullMode(.back)
        commandEncoder.setTriangleFillMode(.lines)

        for submesh in mesh.submeshes {
            print(submesh.indexCount)
            commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
        }
    }
}
