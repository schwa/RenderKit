import Combine
import Everything
import Metal
import MetalKit
import ModelIO
import RenderKitShaders
import simd
import SwiftUI
import SIMDSupport

public class PhongSubrenderer: Subrenderer, ObservableObject {
    @Published
    public var mesh: MTKMesh?

    @Published
    public var material = PhongMaterial(ambientColor: [0.1, 0, 0], diffuseColor: [0.5, 0, 0], specularColor: [1, 1, 1], specularPower: 16)

    @Published
    public var directionalLight = PhongDirectionalLight(direction: [1, 1, 1], ambientColor: [1, 1, 1], diffuseColor: [1, 1, 1], specularColor: [1, 1, 1])

    @Published
    public var yaw: Float = 0

//        @Published
//        var arcball = Arcball(size: [2322, 2022])

    @Published
    public var spaceMouseRotation = RollPitchYaw.identity

    public init(device: MTLDevice, url: URL) throws {
        let allocator = MTKMeshBufferAllocator(device: device)
        let v = try StructureDefinition(key: "Vertex", attributes: [
            .init(name: "position", kind: .float3),
            .init(name: "normal", kind: .float3),
            .init(name: "textureCoordinate", kind: .float2),
        ])
        let vertexDescriptor = v.metalLayout.mdlVertexDescriptor
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: allocator)
        let meshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        guard let mesh = meshes.first else {
            print("No mesh found")
            return
        }
        self.mesh = try MTKMesh(mesh: mesh, device: device)
    }

    public func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        let mtlLibrary = try renderer.device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)

        let vertexFunction = mtlLibrary.makeFunction(name: "phongVertexShader")
        renderPipelineDescriptor.vertexFunction = vertexFunction

        var builder = VertexDescriptorBuilder()
        builder.addAttribute(format: .float3, size: 12) // size of packed float3
        builder.addAttribute(format: .float3, size: 12) // size of packed float3
        builder.addAttribute(format: .float2, size: 8) // size of packed float2
        renderPipelineDescriptor.vertexDescriptor = builder.vertexDescriptor

        let fragmentFunction = mtlLibrary.makeFunction(name: "phongFragmentShader")
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        return renderPipelineDescriptor
    }

    public func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        guard let mtkMesh = mesh else {
            print("No mesh")
            return
        }
        // Compute transforms
        let aspect = Float(renderer.viewport.width) / Float(renderer.viewport.height)
        let fov: Float = degreesToRadians(45)
        let near: Float = 1.0
        let far: Float = 1_000
        let modelTransform =
        simd_float4x4(translate: [0, 0, 0]) * simd_quatf(angle: degreesToRadians(yaw), axis: [0, 1, 0]) * spaceMouseRotation.quat * simd_float4x4(scale: [1, 1, 1])
        let viewTransform = simd_float4x4(translate: [0, 0, -10])
        let projectionTransform = simd_float4x4.perspective(aspect: aspect, fovy: fov, near: near, far: far)

        var uniformsX = UniformsX()
        uniformsX.modelViewProjectionTransform = modelTransform * viewTransform * projectionTransform
        uniformsX.modelViewTransform = modelTransform * viewTransform
        uniformsX.normalTransform = simd_float4x4(simd_float3x3(truncating: modelTransform * viewTransform))
        commandEncoder.setVertexValue(&uniformsX, index: PhongVertexShader.uniforms.rawValue)

        // Set materials
        commandEncoder.setFragmentValue(&material, index: PhongFragmentShader.material.rawValue)

        // Set light
        commandEncoder.setFragmentValue(&directionalLight, index: PhongFragmentShader.light.rawValue)

        // Set Vertex Buffer
        let vertexBuffer = mtkMesh.vertexBuffers[0].buffer
        let offset = mtkMesh.vertexBuffers[0].offset
        commandEncoder.setVertexBuffer(vertexBuffer, offset: offset, index: PhongVertexShader.vertices.rawValue)

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        let depthStencilState = renderer.device.makeDepthStencilState(descriptor: depthDescriptor)

        commandEncoder.setDepthStencilState(depthStencilState)

        // Draw submeshes
        for submesh in mtkMesh.submeshes {
            commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
}
