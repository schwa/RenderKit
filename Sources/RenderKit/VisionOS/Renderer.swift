#if os(visionOS)
import CompositorServices
import Metal
import MetalKit
import simd
import Spatial
import RenderKitShaders
import SwiftUI
import SIMDSupport

public struct ContentStageConfiguration: CompositorLayerConfiguration {
    public init() {
    }

    public func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
        configuration.depthFormat = .depth32Float
        configuration.colorFormat = .bgra8Unorm_srgb
        let foveationEnabled = capabilities.supportsFoveation
        configuration.isFoveationEnabled = foveationEnabled
        let options: LayerRenderer.Capabilities.SupportedLayoutsOptions = foveationEnabled ? [.foveationEnabled] : []
        let supportedLayouts = capabilities.supportedLayouts(options: options)
        configuration.layout = supportedLayouts.contains(.layered) ? .layered : .dedicated
    }
}

public class Renderer {
    let layerRenderer: LayerRenderer
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let maxBuffersInFlight = 3
    let inFlightSemaphore: DispatchSemaphore
    let dynamicUniformBuffer: MTLBuffer
    let alignedUniformsSize = (MemoryLayout<UniformsArray>.size + 0xFF) & -0x100
    var uniforms: UnsafeMutablePointer<UniformsArray>
    let pipelineState: MTLRenderPipelineState
    let depthState: MTLDepthStencilState
    let mesh: MTKMesh
    let colorMap: MTLTexture

    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var rotation: Float = 0
    let arSession: ARKitSession
    let worldTracking: WorldTrackingProvider

    public init(_ layerRenderer: LayerRenderer) throws {
        self.layerRenderer = layerRenderer
        device = layerRenderer.device
        commandQueue = device.makeCommandQueue()!
        inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        dynamicUniformBuffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared])!
        dynamicUniformBuffer.label = "UniformBuffer"
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to: UniformsArray.self, capacity: 1)
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device, layerRenderer: layerRenderer, mtlVertexDescriptor: mtlVertexDescriptor)
        let depthStateDescriptor = MTLDepthStencilDescriptor(depthCompareFunction: .greater, isDepthWriteEnabled: true)
        depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
        worldTracking = WorldTrackingProvider()
        arSession = ARKitSession()
    }

    public func startRenderLoop() {
        Task {
            do {
                try await arSession.run([worldTracking])
            } catch {
                fatalError("Failed to initialize ARSession")
            }
            let renderThread = Thread {
                self.renderLoop()
            }
            renderThread.name = "Render Thread"
            renderThread.start()
        }
    }

    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        let mtlVertexDescriptor = MTLVertexDescriptor()

        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue

        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        return mtlVertexDescriptor
    }

    class func buildRenderPipelineWithDevice(device: MTLDevice, layerRenderer: LayerRenderer, mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        let library = try device.makeDefaultLibrary(bundle: .shadersBundle)
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = layerRenderer.configuration.colorFormat
        pipelineDescriptor.depthAttachmentPixelFormat = layerRenderer.configuration.depthFormat
        pipelineDescriptor.maxVertexAmplificationCount = layerRenderer.properties.viewCount
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    class func buildMesh(device: MTLDevice, mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4), segments: SIMD3<UInt32>(2, 2, 2), geometryType: MDLGeometryType.triangles, inwardNormals: false, allocator: metalAllocator)
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            fatalError()
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        return try MTKMesh(mesh: mdlMesh, device: device)
    }

    class func loadTexture(device: MTLDevice, textureName: String) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        return try textureLoader.newTexture(name: textureName, scaleFactor: 1.0, bundle: Bundle.module, options: [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ])
    }

    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: UniformsArray.self, capacity: 1)
    }

    private func updateGameState(drawable: LayerRenderer.Drawable, deviceAnchor: DeviceAnchor?) {
        /// Update any game state before rendering
        let rotationAxis = SIMD3<Float>(1, 1, 0)
        let modelRotationMatrix = simd_float4x4(rotationAngle: rotation, axis: rotationAxis)
        let modelTranslationMatrix = simd_float4x4(translate: [0, 0, -8])
        let modelMatrix = modelTranslationMatrix * modelRotationMatrix
        let simdDeviceAnchor = deviceAnchor?.originFromAnchorTransform ?? matrix_identity_float4x4
        func uniforms(forViewIndex viewIndex: Int) -> Uniforms {
            let view = drawable.views[viewIndex]
            let viewMatrix = (simdDeviceAnchor * view.transform).inverse
            let projection = ProjectiveTransform3D(leftTangent: Double(view.tangents[0]), rightTangent: Double(view.tangents[1]), topTangent: Double(view.tangents[2]), bottomTangent: Double(view.tangents[3]), nearZ: Double(drawable.depthRange.y), farZ: Double(drawable.depthRange.x), reverseZ: true)
            return Uniforms(projectionMatrix: .init(projection), modelViewMatrix: viewMatrix * modelMatrix)
        }
        self.uniforms[0].uniforms.0 = uniforms(forViewIndex: 0)
        if drawable.views.count > 1 {
            self.uniforms[0].uniforms.1 = uniforms(forViewIndex: 1)
        }
        rotation += 0.01
    }

    func renderFrame() {
        /// Per frame updates hare
        guard let frame = layerRenderer.queryNextFrame() else {
            return
        }
        frame.update {
        }

        guard let timing = frame.predictTiming() else {
            return
        }
        LayerRenderer.Clock().wait(until: timing.optimalInputTime)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Failed to create command buffer")
        }
        guard let drawable = frame.queryDrawable() else {
            return
        }
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        frame.submit {
            let time = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime).timeInterval
            let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: time)
            drawable.deviceAnchor = deviceAnchor
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { _ in
                _ = semaphore.signal()
            }
            updateDynamicBufferState()
            updateGameState(drawable: drawable, deviceAnchor: deviceAnchor)
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.colorTextures[0]
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            renderPassDescriptor.depthAttachment.texture = drawable.depthTextures[0]
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.storeAction = .store
            renderPassDescriptor.depthAttachment.clearDepth = 0.0
            renderPassDescriptor.rasterizationRateMap = drawable.rasterizationRateMaps.first
            if layerRenderer.configuration.layout == .layered {
                renderPassDescriptor.renderTargetArrayLength = drawable.views.count
            }
            /// Final pass rendering code here
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                fatalError("Failed to create render encoder")
            }
            renderEncoder.label = "Primary Render Encoder"
            renderEncoder.pushDebugGroup("Draw Box")
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setDepthStencilState(depthState)
            renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
            let viewports = drawable.views.map { $0.textureMap.viewport }
            renderEncoder.setViewports(viewports)

            if drawable.views.count > 1 {
                var viewMappings = (0..<drawable.views.count).map {
                    MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
                                                      renderTargetArrayIndexOffset: UInt32($0))
                }
                renderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
            }

            for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
                guard let layout = element as? MDLVertexBufferLayout else {
                    return
                }
                if layout.stride != 0 {
                    let buffer = mesh.vertexBuffers[index]
                    renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
                }
            }

            renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
            for submesh in mesh.submeshes {
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
            }

            renderEncoder.popDebugGroup()

            renderEncoder.endEncoding()

            drawable.encodePresent(commandBuffer: commandBuffer)

            commandBuffer.commit()
        }
    }

    func renderLoop() {
        while true {
            if layerRenderer.state == .invalidated {
                print("Layer is invalidated")
                return
            } else if layerRenderer.state == .paused {
                layerRenderer.waitUntilRunning()
                continue
            } else {
                autoreleasepool {
                    self.renderFrame()
                }
            }
        }
    }
}

extension LayerRenderer.Clock.Instant.Duration {
    var timeInterval: TimeInterval {
        let nanoseconds = TimeInterval(components.attoseconds / 1_000_000_000)
        return TimeInterval(components.seconds) + (nanoseconds / TimeInterval(NSEC_PER_SEC))
    }
}

extension LayerRenderer.Frame {
    func update <R>(_ block: () throws -> R) rethrows -> R {
        startUpdate()
        defer {
            endUpdate()
        }
        return try block()
    }
    func submit <R>(_ block: () throws -> R) rethrows -> R {
        startSubmission()
        defer {
            endSubmission()
        }
        return try block()
    }
}
#endif
