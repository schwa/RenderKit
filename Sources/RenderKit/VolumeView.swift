import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import Shaders
import Everything
import MetalSupport

public struct VolumeView: View {
    
    @State
    var renderPass = VolumeRenderPass<MetalViewConfiguration>()
    
    public init() {
    }
    
    public var body: some View {
        RendererView(renderPass: $renderPass)
    }
}

struct VolumeRenderPass<Configuration>: RenderPass where Configuration: RenderKitConfiguration {
    let id = LOLID2(prefix: "VolumeRenderPass")
    var scene: SimpleScene?
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var texture: MTLTexture
    var cache = Cache<String, Any>()

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
                let library = try! device.makeDefaultLibrary(bundle: .shaders)
                let vertexFunction = library.makeFunction(name: "volumeVertexShader")!
                let fragmentFunction = library.makeFunction(name: "volumeFragmentShader")

                // TODO: This is silly...
                let plane = try! MTKMesh(mesh: Plane().toMDLMesh(extent: [2, 2, 0], allocator: MTKMeshBufferAllocator(device: device)), device: device)

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
                renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(plane.vertexDescriptor)
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

                let camera = Camera(transform: .translation([0, 0, 2]), target: .zero, projection: .perspective(PerspectiveProjection(fovy: .degrees(90), zClip: 0.1 ... 100)))

                // Vertex Buffer Index 0
//                let mesh = try cache.get(key: "cube", of: MTKMesh.self) {
//                    let allocator = MTKMeshBufferAllocator(device: configuration.device!)
//                    let mdlMesh = Cube().toMDLMesh(extent: [1, 1, 1], allocator: allocator)
//                    return try MTKMesh(mesh: mdlMesh, device: configuration.device!)
//                }
//                encoder.setVertexBuffer(mesh, startingIndex: 0)

                let mesh2 = try cache.get(key: "mesh2", of: SimpleMesh.self) {
                    let rect = CGRect(center: .zero, radius: 0.5)
                    let circle = LegacyGraphics.Circle(containing: rect)
                    let triangle = Triangle(containing: circle)
                    return try SimpleMesh(label: "triangle", triangle: triangle, device: configuration.device!)
                }
                encoder.setVertexBuffer(mesh2, index: 0)

                // Vertex Buffer Index 1
                let cameraUniforms = CameraUniforms(projectionMatrix: camera.projection.matrix(viewSize: SIMD2<Float>(size)))
                encoder.setVertexBytes(of: cameraUniforms, index: 1)

                // Vertex Buffer Index 2
                let modelUniforms = ModelUniforms(
                    modelViewMatrix: camera.transform.matrix.inverse * .identity,
                    modelNormalMatrix: simd_float3x3(truncating: .identity.transpose.inverse),
                    color: [1, 0, 0, 0]
                )
                encoder.setVertexBytes(of: modelUniforms, index: 2)
                
                // Vertex Buffer Index 3
                let instances = [
                    VolumeInstance(slice: 0, textureZ: 0.0, offset: .zero),
                ]
                encoder.setVertexBytes(of: instances, index: 3)

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

                
//                for submesh in mesh.submeshes {
//                    encoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset, instanceCount: instances.count)
//                }

                encoder.draw(mesh2, instanceCount: 1)
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
//    var vertexDescriptor: MTLVertexDescriptor = {
//        let d = MTLVertexDescriptor()
//        fatalError()
//        return d
//    }()

    
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
        self = .init(label: label, indexCount: indices.count, indexBuffer: indexBuffer, vertexBuffer: vertexBuffer)
    }
}

extension SimpleMesh {
    init(label: String? = nil, triangle: Triangle, transform: simd_float3x2 = simd_float3x2([1, 0], [0, 0], [0, 1]), device: MTLDevice) throws {
        let vertices = [
            SIMD2<Float>(triangle.vertex.0),
            SIMD2<Float>(triangle.vertex.1),
            SIMD2<Float>(triangle.vertex.2),
        ]
        .map {
            // TODO; Normal not impacted by transform. It should be.
            Vertex(position: $0 * transform, normal: [0, 0, 1], textureCoordinate: $0)
        }
        print(vertices)
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
