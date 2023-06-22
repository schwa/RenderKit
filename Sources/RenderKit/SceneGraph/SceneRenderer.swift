import Everything
import Foundation
import MetalKit
import simd
import SwiftUI
import RenderKitShaders

#if canImport(ARKit)
import ARKit
#endif

public class SceneRenderer: ShaderLibraryBasedSubrenderer {
    public private(set) var sceneGraph: Scene
    
    public init(device: MTLDevice, sceneGraph: Scene) throws {
        self.sceneGraph = sceneGraph
        
        let mtlLibrary = try device.makeDefaultLibrary(bundle: Bundle.renderKitShaders)
        
        let shaderLibrary = try ShaderLibrary(
            mtlLibrary: mtlLibrary,
            types: [
                .init(key: "Vertex", attributes: [
                    .init(name: "position", kind: .float3),
                    .init(name: "normal", kind: .float3),
                    .init(name: "textureCoordinate", kind: .float2),
                ]),
                .init(key: "Transforms", attributes: [
                    .init(name: "modelView", kind: .float4x4), // TODO: 4x3
                    .init(name: "projection", kind: .float4x4), // TODO: 4x3
                    .init(name: "normal", kind: .float4x4), // TODO: 3x3
                ]),
                .init(key: "PhongMaterial", attributes: [
                    .init(name: "ambientColor", kind: .float3),
                    .init(name: "diffuseColor", kind: .float3),
                    .init(name: "specularColor", kind: .float3),
                    .init(name: "specularPower", kind: .float),
                ]),
                .init(key: "DirectionalLight", attributes: [
                    .init(name: "direction", kind: .float3),
                    .init(name: "ambientColor", kind: .float3),
                    .init(name: "diffuseColor", kind: .float3),
                    .init(name: "specularColor", kind: .float3),
                ]),
            ],
            shaders: [
                .init(name: "phongVertexShader", type: .vertex, parameters: [
                    .init(name: "vertices", index: .init(rawValue: 0), typeName: "Vertex", kind: .buffer),
                    .init(name: "transforms", index: .init(rawValue: 1), typeName: "Transforms", kind: .uniform),
                ]),
                .init(name: "phongFragmentShader", type: .fragment, parameters: [
                    .init(name: "material", index: .init(rawValue: 2), typeName: "PhongMaterial", kind: .uniform),
                    .init(name: "light", index: .init(rawValue: 3), typeName: "DirectionalLight", kind: .uniform),
                ]),
            ]
        )
        try super.init(device: device, shaderLibrary: shaderLibrary)
    }
    
    override public func makePipelineDescriptor(renderer: Renderer) throws -> MTLRenderPipelineDescriptor {
        let renderPipelineDescriptor = try super.makePipelineDescriptor(renderer: renderer)
        
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        return renderPipelineDescriptor
    }
    
    override public func encode(renderer: Renderer, commandEncoder: MTLRenderCommandEncoder) throws {
        // Set up depth (TODO: most of this can be done earlier)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        let depthStencilState = renderer.device.makeDepthStencilState(descriptor: depthDescriptor)
        commandEncoder.setDepthStencilState(depthStencilState)
        
        // Compute projection from camera
        let projection: simd_float4x4
        let viewTransform: simd_float4x4
        guard let camera = sceneGraph.currentCamera else {
            return
        }
        let aspect = Float(renderer.viewport.width) / Float(renderer.viewport.height)
        switch camera {
        case let camera as PerspectiveCamera:
            projection = simd_float4x4.perspective(aspect: aspect, fovy: camera.fovy, near: camera.near, far: camera.far)
            viewTransform = camera.transform.matrix
        default:
            fatalError()
        }
        
        // Setup light uniform
        let directionalLight = PhongDirectionalLight(direction: [1, 1, 1], ambientColor: [1, 1, 1], diffuseColor: [1, 1, 1], specularColor: [1, 1, 1])
        //    let ambientLight = AmbientLight(color: [1, 1, 1])
        let lightType = shaderLibrary.types[fragmentShader.light.typeName!]!
        var light = Accessor<[UInt8], DynamicRow>(layout: lightType.metalLayout, count: 1)
        light[0].direction = directionalLight.direction
        //    light[0].ambientColor = ambientLight.color
        light[0].diffuseColor = directionalLight.diffuseColor
        light[0].specularColor = directionalLight.specularColor
        commandEncoder.setFragmentBytes(light.storage, index: fragmentShader.light.index.rawValue)
        
        // Prepare transforms uniform
        let transformsType = shaderLibrary.types[vertexShader.transforms.typeName!]!
        var transforms = Accessor<[UInt8], DynamicRow>(layout: transformsType.metalLayout, count: 1)
        transforms[0].projection = projection
        
        // #############################
        
        sceneGraph.rootNode.walk { node in
            
            // TODO: Does not handle nested transforms
            let modelTransform = node.transform.matrix
            
            transforms[0].modelView = modelTransform * viewTransform
            transforms[0].normal = simd_float4x4(simd_float3x3(truncating: modelTransform * viewTransform))
            commandEncoder.setVertexBytes(transforms.storage, index: vertexShader.transforms.index.rawValue)
            
            switch node {
            case let modelNode as ModelEntity:
                self.render(modelNode, commandEncoder: commandEncoder)
            default:
                // print("Cannot render \(node)")
                break
            }
        }
    }
    
    func render(_ entity: ModelEntity, commandEncoder: MTLRenderCommandEncoder) {
        // Set materials
        let materialType = shaderLibrary.types[fragmentShader.material.typeName!]!
        var material = Accessor<[UInt8], DynamicRow>(layout: materialType.metalLayout, count: 1)
        material[0].ambientColor = entity.material.ambientColor
        material[0].diffuseColor = entity.material.diffuseColor
        material[0].specularColor = entity.material.specularColor
        material[0].specularPower = entity.material.specularPower
        commandEncoder.setFragmentBytes(material.storage, index: fragmentShader.material.index.rawValue)
        
        let vertexBuffer = entity.mesh.vertexBuffers[0].buffer
        let offset = entity.mesh.vertexBuffers[0].offset
        commandEncoder.setVertexBuffer(vertexBuffer, offset: offset, index: vertexShader.vertices.index.rawValue)
        
        for submesh in entity.mesh.submeshes {
            commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
}

#if canImport(ARKit)
// swiftlint:disable:next extension_access_modifier
public extension ARGeometrySource {
    override var description: String {
        return "<ARGeometrySource: XXXX> (buffer: \(buffer), count: \(count), format: \(format), componentsPerVector: \(componentsPerVector), offset: \(offset), stride: \(stride)"
    }
}

// swiftlint:disable:next extension_access_modifier
public extension ARGeometryElement {
    override var description: String {
        return "<ARGeometrySource: XXXX> (buffer: \(buffer), count: \(count), bytesPerIndex: \(bytesPerIndex), indexCountPerPrimitive: \(indexCountPerPrimitive), primitiveType: \(primitiveType)"
    }
}
#endif
