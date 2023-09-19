import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import Shaders
import Everything
import MetalSupport

// https://www.youtube.com/watch?v=y4KdxaMC69w&t=1761s

public struct VolumeView: View {
    
    @State
    var renderPass = VolumeRenderPass<MetalViewConfiguration>()
    
    @State
    var rotation = Rotation.zero
    
    public init() {
    }
    
    public var body: some View {
        RendererView(renderPass: $renderPass)
            .ballRotation($rotation)
            .onChange(of: rotation) {
                renderPass.rotation = rotation
            }
    }
}

struct VolumeRenderPass<Configuration>: RenderPass where Configuration: RenderKitConfiguration {
    let id = LOLID2(prefix: "VolumeRenderPass")
    var scene: SimpleScene?
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var texture: MTLTexture
    var cache = Cache<String, Any>()
    var rotation: Rotation = .zero
    
    init() {
        let url = Bundle.main.resourceURL!.appendingPathComponent("StanfordVolumeData/CThead")
        let volumeData = VolumeData(directoryURL: url, size: [256, 256, 113])
        let load = try! volumeData.load()
        texture = try! load(MTLCreateSystemDefaultDevice()!)
        let id = id
        logger?.debug("\(id): \(#function)")
    }
    
    mutating func setup(configuration: inout Configuration.Update) {
        let id = id
        logger?.debug("\(id): \(#function)")
        guard let device = configuration.device else {
            fatalError("No metal device")
        }
        do {
            if renderPipelineState == nil {
                let library = try! device.makeDebugLibrary(bundle: .shadersBundle)
                let vertexFunction = library.makeFunction(name: "volumeVertexShader")!
                let fragmentFunction = library.makeFunction(name: "volumeFragmentShader")

                let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
                renderPipelineDescriptor.vertexFunction = vertexFunction
                renderPipelineDescriptor.fragmentFunction = fragmentFunction
                renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat

                renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
                renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
                renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
                renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;
                renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha;
                renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

                renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
                renderPipelineDescriptor.vertexDescriptor = SimpleMesh.vertexDescriptor
                renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            }

            if depthStencilState == nil {
                let depthStencilDescriptor = MTLDepthStencilDescriptor()
                depthStencilDescriptor.depthCompareFunction = .lessEqual
                depthStencilDescriptor.isDepthWriteEnabled = true
                depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
            }

        }
        catch {
            fatalError()
        }
        
    }
    
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) {
        let id = id
        logger?.debug("\(id): \(#function)")
        guard let renderPipelineState, let depthStencilState else {
            let id = id
            logger?.debug("\(id): \(#function): missing renderPipelineState or depthStencilState")
            return
        }
    }

    
    func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer) {
//        logger?.debug("\(#function)")
        do {
            guard let renderPipelineState, let depthStencilState else {
                let id = id
                logger?.debug("\(id): \(#function): missing renderPipelineState or depthStencilState")
                return
            }
            guard let renderPassDescriptor = configuration.currentRenderPassDescriptor, let size = configuration.size else {
                fatalError("No current render pass descriptor.")
            }
            try commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
                encoder.setRenderPipelineState(renderPipelineState)
                encoder.setDepthStencilState(depthStencilState)

                let camera = Camera(transform: .init( translation: [0, 0, 2]), target: .zero, projection: .perspective(PerspectiveProjection(fovy: .degrees(90), zClip: 0.01 ... 10)))

                let modelTransform = Transform(rotation: rotation.quaternion)
                
                let mesh2 = try cache.get(key: "mesh2", of: SimpleMesh.self) {
                    let rect = CGRect(center: .zero, radius: 0.5)
                    let circle = LegacyGraphics.Circle(containing: rect)
                    let triangle = Triangle(containing: circle)
//                    return try SimpleMesh(label: "triangle", triangle: triangle, device: configuration.device!) {
//                        SIMD2<Float>($0) + [0.5, 0.5]
//                    }
                    return try SimpleMesh(label: "rectangle", rectangle: rect, device: configuration.device!) {
                        SIMD2<Float>($0) + [0.5, 0.5]
                    }
                }
                encoder.setVertexBuffer(mesh2, index: 0)

                // Vertex Buffer Index 1
                let cameraUniforms = CameraUniforms(projectionMatrix: camera.projection.matrix(viewSize: SIMD2<Float>(size)))
                encoder.setVertexBytes(of: cameraUniforms, index: 1)

                // Vertex Buffer Index 2
                let modelUniforms = ModelUniforms(
                    modelViewMatrix: camera.transform.matrix.inverse * modelTransform.matrix,
                    modelNormalMatrix: simd_float3x3(truncating: modelTransform.matrix.transpose.inverse),
                    color: [1, 0, 0, 0]
                )
                encoder.setVertexBytes(of: modelUniforms, index: 2)
                
                // Vertex Buffer Index 3
                
                let instances = cache.get(key: "instance_data", of: MTLBuffer.self) {
                    let instances = (0..<texture.depth).map { slice in
                        let z = Float(slice) / Float(texture.depth - 1)
                        return VolumeInstance(offsetZ: z, textureZ: z)
                    }
                    let buffer = configuration.device!.makeBuffer(bytesOf: instances, options: .storageModeShared)!
                    buffer.label = "instances"
                    assert(buffer.length == 8 * texture.depth)
                    return buffer
                }
                encoder.setVertexBuffer(instances, offset: 0, index: 3)

                let sampler = cache.get(key: "sampler", of: MTLSamplerState.self) {
                    let samplerDescriptor = MTLSamplerDescriptor()
                    samplerDescriptor.label = "Default sampler"
                    samplerDescriptor.normalizedCoordinates = true
                    samplerDescriptor.minFilter = .linear
                    samplerDescriptor.magFilter = .linear
                    samplerDescriptor.mipFilter = .linear
                    return configuration.device!.makeSamplerState(descriptor: samplerDescriptor)!
                }

                encoder.setFragmentSamplerState(sampler, index: 0)
                encoder.setFragmentTexture(texture, index: 0)

//                encoder.setTriangleFillMode(.lines)
//                print(texture.depth)
                encoder.draw(mesh2, instanceCount: texture.depth)
            }
        }
        catch {
            logger?.error("Render error: \(error)")
        }
    }
}

import LegacyGraphics

extension LegacyGraphics.Circle {
    init(containing rect: CGRect) {
        let center = rect.midXMidY
        let diameter = sqrt(rect.width ** 2 + rect.height ** 3)
        self = .init(center: center, diameter: diameter)
    }
}

extension Triangle {
    init(containing circle: LegacyGraphics.Circle) {
        let a = circle.center + CGPoint(length: circle.radius * 2, angle: Angle.degrees(0).radians)
        let b = circle.center + CGPoint(length: circle.radius * 2, angle: Angle.degrees(120).radians)
        let c = circle.center + CGPoint(length: circle.radius * 2, angle: Angle.degrees(240).radians)
        self = .init(a, b, c)
    }
}



struct SimpleMesh {
    let label: String?
    var indexCount: Int
    var indexBuffer: MTLBuffer
    var vertexBuffer: MTLBuffer

    var primitiveType: MTLPrimitiveType {
        .triangle
    }
    var indexType: MTLIndexType { .uint16 }
    var indexBufferOffset: Int { 0 }
    var vertexBufferOffset: Int { 0 }
    static var vertexDescriptor: MTLVertexDescriptor = {
        assert(MemoryLayout<Vertex>.size == 40)

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stride = 40
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[2].offset = 32
        vertexDescriptor.attributes[2].format = .float2
        return vertexDescriptor
    }()

    
    init(label: String? = nil, indexCount: Int, indexBuffer: MTLBuffer, vertexBuffer: MTLBuffer) {
        self.label = label
        self.indexCount = indexCount
        self.indexBuffer = indexBuffer
        self.vertexBuffer = vertexBuffer
        if let label {
            indexBuffer.label = "\(label)-indices"
            vertexBuffer.label = "\(label)-vertices"
        }
    }
}

extension SimpleMesh {
    init(label: String? = nil, indices: [UInt16], vertices: [Vertex], device: MTLDevice) throws {
        guard let indexBuffer = device.makeBuffer(bytesOf: indices, options: .storageModePrivate) else {
            fatalError()
        }
        guard let vertexBuffer = device.makeBuffer(bytesOf: vertices, options: .storageModePrivate) else {
            fatalError()
        }
        assert(vertexBuffer.length == vertices.count * 40)
        self = .init(label: label, indexCount: indices.count, indexBuffer: indexBuffer, vertexBuffer: vertexBuffer)
    }
}

extension SimpleMesh {
    init(label: String? = nil, rectangle: CGRect, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws {
        // 1---3
        // |\  |
        // | \ |
        // |  \|
        // 0---2

        let vertices = [
            rectangle.minXMinY,
            rectangle.minXMaxY,
            rectangle.maxXMinY,
            rectangle.maxXMaxY,
        ]
        .map {
            // TODO; Normal not impacted by transform. It should be.
            Vertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
        }
        self = try .init(label: label, indices: [0, 1, 2, 1, 3, 2], vertices: vertices, device: device)
    }
}

extension SimpleMesh {
    init(label: String? = nil, triangle: Triangle, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 1], [0, 0]), device: MTLDevice, textureCoordinate: (CGPoint) -> SIMD2<Float>) throws {
        let vertices = [
            triangle.vertex.0,
            triangle.vertex.1,
            triangle.vertex.2,
        ]
        .map {
            // TODO; Normal not impacted by transform. It should be.
            Vertex(position: SIMD2<Float>($0) * transform, normal: [0, 0, 1], textureCoordinate: textureCoordinate($0))
        }
        self = try .init(label: label, indices: [0, 1, 2], vertices: vertices, device: device)
    }
}


extension MTLRenderCommandEncoder {
    func setVertexBuffer(_ mesh: SimpleMesh, index: Int) {
        setVertexBuffer(mesh.vertexBuffer, offset: mesh.vertexBufferOffset, index: index)
    }
    
    func draw(_ mesh: SimpleMesh) {
        drawIndexedPrimitives(type: mesh.primitiveType, indexCount: mesh.indexCount, indexType: mesh.indexType, indexBuffer: mesh.indexBuffer, indexBufferOffset: mesh.indexBufferOffset)
    }
    
    func draw(_ mesh: SimpleMesh, instanceCount: Int) {
        drawIndexedPrimitives(type: mesh.primitiveType, indexCount: mesh.indexCount, indexType: mesh.indexType, indexBuffer: mesh.indexBuffer, indexBufferOffset: mesh.indexBufferOffset, instanceCount: instanceCount)
    }
}
