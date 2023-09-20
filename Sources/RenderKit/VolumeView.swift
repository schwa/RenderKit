import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import Shaders
import Everything
import MetalSupport
import os

// https://www.youtube.com/watch?v=y4KdxaMC69w&t=1761s

public struct VolumeView: View {
    
    @State
    var renderPass = VolumeRenderPass<MetalViewConfiguration>()
    
    @State
    var rotation = Rotation.zero
    
    @State
    var volumeData = VolumeData(named: "CThead", size: [256, 256, 113])
    
    @State
    var redTransferFunction: [Float] = Array(repeating: 1.0, count: 256)
    @State
    var greenTransferFunction: [Float] = Array(repeating: 1.0, count: 256)
    @State
    var blueTransferFunction: [Float] = Array(repeating: 1.0, count: 256)
    @State
    var alphaTransferFunction: [Float] = (0..<256).map({ Float($0) / Float(255) })

    @Environment(\.metalDevice)
    var device
    
    public init() {
    }
    
    public var body: some View {
        RendererView(renderPass: $renderPass)
            .ballRotation($rotation, pitchLimit: .degrees(-.infinity) ... .degrees(.infinity), yawLimit: .degrees(-.infinity) ... .degrees(.infinity))
            .onAppear {
                updateTransferFunctionTexture()
            }
            .onChange(of: rotation) {
                renderPass.rotation = rotation
            }
            .onChange(of: redTransferFunction) {
                updateTransferFunctionTexture()
            }
            .onChange(of: greenTransferFunction) {
                updateTransferFunctionTexture()
            }
            .onChange(of: blueTransferFunction) {
                updateTransferFunctionTexture()
            }
            .onChange(of: alphaTransferFunction) {
                updateTransferFunctionTexture()
            }
            .overlay(alignment: .bottom) {
                VStack {
                    TransferFunctionEditor(width: 1024, values: $redTransferFunction, color: .red)
                        .frame(maxHeight: 20)
                    TransferFunctionEditor(width: 1024, values: $greenTransferFunction, color: .green)
                        .frame(maxHeight: 20)
                    TransferFunctionEditor(width: 1024, values: $blueTransferFunction, color: .blue)
                        .frame(maxHeight: 20)
                    TransferFunctionEditor(width: 1024, values: $alphaTransferFunction, color: .white)
                        .frame(maxHeight: 20)
                }
                .background(.ultraThinMaterial)
                .padding()
                .controlSize(.small)
            }
    }
    
    func updateTransferFunctionTexture() {

        let values = (0...255).map {
            SIMD4<Float>(
                redTransferFunction[$0],
                greenTransferFunction[$0],
                blueTransferFunction[$0],
                alphaTransferFunction[$0]
            )
        }
        .map { $0 * 255.0 }
        .map { SIMD4<UInt8>($0) }
        
        values.withUnsafeBytes { buffer in
            let region = MTLRegion(origin: [0, 0, 0], size: [256, 1, 1]) // TODO: Hardcoded
            let bytesPerRow = 256 * MemoryLayout<SIMD4<UInt8>>.stride
            
            
            renderPass.transferFunctionTexture.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: buffer.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: 0)
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
    var transferFunctionTexture: MTLTexture
    var logger: Logger? = nil
    
    init() {
        let device = MTLCreateSystemDefaultDevice()! // TODO: Naughty
        let volumeData = VolumeData(named: "CThead", size: [256, 256, 113]) // TODO: Hardcoded
//        let volumeData = VolumeData(named: "MRBrain", size: [256, 256, 109])
        let load = try! volumeData.load()
        texture = try! load(device)
        let id = id
        logger?.debug("\(id): \(#function)")

        // TODO: Hardcoded
        let textureDescriptor = MTLTextureDescriptor()
        // We actually only need this texture to be 1D but Metal doesn't allow buffer backed 1D textures which seems assinine. Maybe we don't need it to be buffer backed and just need to call texture.copy each update?
        textureDescriptor.textureType = .type1D
        textureDescriptor.width = 256 // TODO: Hardcoded
        textureDescriptor.height = 1
        textureDescriptor.depth = 1
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError()
        }
        texture.label = "transfer function"
        transferFunctionTexture = texture
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
                renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
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

                let modelTransform = Transform(scale: [2, 2, 2], rotation: rotation.quaternion)
                
                let mesh2 = try cache.get(key: "mesh2", of: SimpleMesh.self) {
                    let rect = CGRect(center: .zero, radius: 0.5)
                    let circle = LegacyGraphics.Circle(containing: rect)
                    let triangle = Triangle(containing: circle)
                    return try SimpleMesh(label: "triangle", triangle: triangle, device: configuration.device!) {
                        SIMD2<Float>($0) + [0.5, 0.5]
                    }
//                    return try SimpleMesh(label: "rectangle", rectangle: rect, device: configuration.device!) {
//                        SIMD2<Float>($0) + [0.5, 0.5]
//                    }
                }
                encoder.setVertexBuffer(mesh2, index: 0)

                // Vertex Buffer Index 1
                let cameraUniforms = CameraUniforms(projectionMatrix: camera.projection.matrix(viewSize: SIMD2<Float>(size)))
                encoder.setVertexBytes(of: cameraUniforms, index: 1)

                // Vertex Buffer Index 2
                let modelUniforms = VolumeTransforms(
                    modelViewMatrix: camera.transform.matrix.inverse * modelTransform.matrix,
                    textureMatrix: simd_float4x4(translate: [0.5, 0.5, 0.5]) * rotation.matrix * simd_float4x4(translate: [-0.5, -0.5, -0.5])
                )
                encoder.setVertexBytes(of: modelUniforms, index: 2)
                
                // Vertex Buffer Index 3
                
                let instanceCount = 256 // TODO: Random - numbers as low as 32 - but you will see layering in the image.
                
                let instances = cache.get(key: "instance_data", of: MTLBuffer.self) {
                    
                    let instances = (0..<instanceCount).map { slice in
                        let z = Float(slice) / Float(instanceCount - 1)
                        return VolumeInstance(offsetZ: z - 0.5, textureZ: 1 - z)
                    }
                    let buffer = configuration.device!.makeBuffer(bytesOf: instances, options: .storageModeShared)!
                    buffer.label = "instances"
                    assert(buffer.length == 8 * instanceCount)
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
                encoder.setFragmentTexture(transferFunctionTexture, index: 1)

                // TODO: Hard coded
                let fragmentUniforms = VolumeFragmentUniforms(instanceCount: UInt16(instanceCount), maxValue: 3272, alpha: 10.0)
                encoder.setFragmentBytes(of: fragmentUniforms, index: 0)
                
                encoder.draw(mesh2, instanceCount: instanceCount)
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
        guard let indexBuffer = device.makeBuffer(bytesOf: indices, options: .storageModeShared) else {
            fatalError()
        }
        guard let vertexBuffer = device.makeBuffer(bytesOf: vertices, options: .storageModeShared) else {
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

struct TransferFunctionEditor: View {
    
    
    let width: Int
    
    @Binding
    var values: [Float]
    
    let color: Color
    
    @State
    var lastLocation: CGFloat?

    let coordinateSpace = NamedCoordinateSpace.named(ObjectIdentifier(Self.self))
    
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.scaleBy(x: 1, y: -1)
                context.translateBy(x: 0, y: -size.height)
                context.scaleBy(x: size.width / Double(values.count), y: 1)
                let path = Path { path in
                    path.move(to: .zero)
                    for (index, value) in values.enumerated() {
                        path.addLine(to: CGPoint(Double(index), Double(value) * size.height))
                    }
                    path.addLine(to: CGPoint(x: 1023, y: 0))
                    path.closeSubpath()
                }
                context.fill(path, with: .color(color))
            }
            .coordinateSpace(coordinateSpace)
            .gesture(DragGesture(coordinateSpace: coordinateSpace ).onChanged({ value in
                let column = clamp(Int(value.location.x * Double(values.count - 1) / proxy.size.width), in: 0...(values.count - 1))
                let value = clamp(1 - Float(value.location.y / proxy.size.height), in: 0...1)
                values[column] = value
            }))
        }
        .contextMenu {
            Button("Clear") {
                values = Array(repeating: 0, count: values.count)
            }
            Button("Set") {
                values = Array(repeating: 1, count: values.count)
            }
            Button("Ramp Up") {
                values = (0..<values.count).map { Float($0) / Float(values.count) }
            }
            Button("Ramp Down") {
                values = (0..<values.count).map { 1 - Float($0) / Float(values.count) }
            }
        }
    }
    
}

extension MTLOrigin: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Int...) {
        self = .init(x: elements[0], y: elements[2], z: elements[2])
    }
}

