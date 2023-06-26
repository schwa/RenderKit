import SwiftUI
import MetalKit
import ModelIO
import simd
import Everything
import MetalSupport
import SIMDSupport

public struct OffscreenDemo {
    public class Configuration {
        public var size = CGSize(width: 1920, height: 1080)

        public var device: MTLDevice?
        public var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
        public var depthStencilPixelFormat: MTLPixelFormat = .invalid
        public var currentRenderPassDescriptor: MTLRenderPassDescriptor?
        public var targetTexture: MTLTexture?

        public init() {
        }

        public func update() {
            currentRenderPassDescriptor = nil
            targetTexture = nil

            guard let device else {
                return
            }

            let targetTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
            targetTextureDescriptor.storageMode = .shared
            targetTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            let targetTexture = device.makeTexture(descriptor: targetTextureDescriptor)!
            targetTexture.label = "Output"

            let currentRenderPassDescriptor = MTLRenderPassDescriptor()
            currentRenderPassDescriptor.colorAttachments[0].texture = targetTexture
            currentRenderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            currentRenderPassDescriptor.colorAttachments[0].storeAction = .store

            self.currentRenderPassDescriptor = currentRenderPassDescriptor
            self.targetTexture = targetTexture
        }
    }

    public var commandQueue: MTLCommandQueue?
    public var shaderToyRenderPipelineState: MTLRenderPipelineState?
    public var plane: MTKMesh?
    public var pixelate = false
    public var scale = SIMD2<Float>(16, 16)
    public var speed = Float(1)
    public var time = Float(0)
    public var texture: MTLTexture?
    public var sampler: MTLSamplerState?

    public init() {
    }

    public mutating func setup(configuration: Configuration) {
        guard let device = configuration.device else {
            fatalError("No metal device")
        }
        let library = try! device.makeDefaultLibrary(bundle: .module)
        let constants = MTLFunctionConstantValues()

        let textureLoader = MTKTextureLoader(device: device)
        texture = try! textureLoader.newTexture(name: "HD-Testcard-original", scaleFactor: 1.0, bundle: .module)

        let samplerDescriptor = MTLSamplerDescriptor()
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)

        let vertexFunction = try! library.makeFunction(name: "demoBlitVertexShader", constantValues: constants)
        let fragmentFunction = try! library.makeFunction(name: "demoBlitFragmentShader", constantValues: constants)
        let plane = try! MTKMesh(mesh: Plane().toMDLMesh(extent: [2, 2, 0], allocator: MTKMeshBufferAllocator(device: device)), device: device)
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
        renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(plane.vertexDescriptor)
        let commandQueue = device.makeCommandQueue()
        let shaderToyRenderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        self.plane = plane
        self.commandQueue = commandQueue
        self.shaderToyRenderPipelineState = shaderToyRenderPipelineState
    }

    public func draw(configuration: Configuration) {
        guard let device = configuration.device, let commandQueue, let plane, let shaderToyRenderPipelineState else {
            logger.warning("Not ready to draw.")
            return
        }

        var captureScope: MTLCaptureScope?
        if false {
            let captureManager = MTLCaptureManager.shared()
            captureScope = captureManager.makeCaptureScope(device: device)
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = captureScope
            try! captureManager.startCapture(with: captureDescriptor)
            captureScope?.begin()
        }

        commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
            guard let renderPassDescriptor = configuration.currentRenderPassDescriptor else {
                logger.warning("No current render pass descriptor.")
                return
            }
            commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
                encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(configuration.size.width), height: Double(configuration.size.height), znear: 0, zfar: 1))
                encoder.setCullMode(.back)
                encoder.setRenderPipelineState(shaderToyRenderPipelineState)
                //
                encoder.setVertexBytes(of: simd_float4x3.identity, index: 1)
                //

                encoder.setFragmentTexture(texture, index: 0)
                encoder.setFragmentSamplerState(sampler, index: 0)

                //
                encoder.draw(plane)
            }
        }

        captureScope?.end()
    }
}
