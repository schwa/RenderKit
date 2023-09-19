import SwiftUI
import MetalKit
import ModelIO
import simd
import Everything
import MetalSupport
import SIMDSupport

// TODO: Struct?
public struct OffscreenRenderPassConfiguration: RenderKitConfiguration, RenderKitUpdateConfiguration, RenderKitDrawConfiguration {
    public typealias Update = Self
    public typealias Draw = Self

    public var currentDrawable: CAMetalDrawable?
    
    public var preferredFramesPerSecond: Int = 120
    
    // TODO: INVENTED VALUES
    public var depthStencilAttachmentTextureUsage: MTLTextureUsage = .renderTarget
    public var depthStencilStorageMode: MTLStorageMode = .shared
    // TODO: DONE

    public var size: CGSize? = CGSize(width: 1920, height: 1080)

    public var device: MTLDevice?
    public var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    public var depthStencilPixelFormat: MTLPixelFormat = .invalid
    public var depthStencilTexture: MTLTexture?
    public var currentRenderPassDescriptor: MTLRenderPassDescriptor?
    public var targetTexture: MTLTexture?
    public var clearColor: MTLClearColor = .init(red: 0, green: 0, blue: 0, alpha: 1.0)
    public var clearDepth: Double = 1.0

    public init() {
    }

    public mutating func update() {
        currentRenderPassDescriptor = nil
        targetTexture = nil

        guard let device, let size else {
            return
        }

        let currentRenderPassDescriptor = MTLRenderPassDescriptor()

        let targetTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
        targetTextureDescriptor.storageMode = .shared
        targetTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let targetTexture = device.makeTexture(descriptor: targetTextureDescriptor)!
        targetTexture.label = "Target Texture"
        currentRenderPassDescriptor.colorAttachments[0].texture = targetTexture
        currentRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        currentRenderPassDescriptor.colorAttachments[0].storeAction = .store
        self.targetTexture = targetTexture

        if depthStencilPixelFormat != .invalid {
            let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthStencilPixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
            depthTextureDescriptor.storageMode = .private
            depthTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            let depthStencilTexture = device.makeTexture(descriptor: depthTextureDescriptor)!
            depthStencilTexture.label = "Depth Texture"
            currentRenderPassDescriptor.depthAttachment.texture = depthStencilTexture
            currentRenderPassDescriptor.depthAttachment.loadAction = .clear
            currentRenderPassDescriptor.depthAttachment.storeAction = .store
            self.depthStencilTexture = depthStencilTexture
        }

        self.currentRenderPassDescriptor = currentRenderPassDescriptor
    }
}

public protocol RenderPass {

    associatedtype Configuration: RenderKitConfiguration

    mutating func setup(configuration: inout Configuration.Update)
    mutating func resized(configuration: inout Configuration.Update, size: CGSize)
    func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer)
}

extension RenderPass {
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) {
    }
}

public struct OffscreenDemoRenderPass <Configuration>: RenderPass where Configuration: RenderKitConfiguration {
    public var shaderToyRenderPipelineState: MTLRenderPipelineState?
    public var plane: MTKMesh?
    public var pixelate = false
    public var scale = SIMD2<Float>(16, 16)
    public var speed = Float(1)
    public var time = Float(0)
    public var texture: MTLTexture?
    public var sampler: MTLSamplerState?
    public var capture = false

    public init() {
    }

    public mutating func setup(configuration: inout Configuration.Update) {
        guard let device = configuration.device else {
            fatalError("No metal device")
        }
        let library = try! device.makeDefaultLibrary(bundle: .shaders)
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
        let shaderToyRenderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        self.plane = plane
        self.shaderToyRenderPipelineState = shaderToyRenderPipelineState
    }
    
    public mutating func resized(configuration: inout Configuration.Update, size: CGSize) {
        
    }


    public func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer) {
        guard let device = configuration.device, let plane, let shaderToyRenderPipelineState, let size = configuration.size else {
            logger.warning("Not ready to draw.")
            return
        }

        var captureScope: MTLCaptureScope?
        if capture {
            let captureManager = MTLCaptureManager.shared()
            captureScope = captureManager.makeCaptureScope(device: device)
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = captureScope
            try! captureManager.startCapture(with: captureDescriptor)
            captureScope?.begin()
        }

        guard let renderPassDescriptor = configuration.currentRenderPassDescriptor else {
            logger.warning("No current render pass descriptor.")
            return
        }
        commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
            encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(size.width), height: Double(size.height), znear: 0, zfar: 1))
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

        captureScope?.end()
    }
}

#if os(macOS)
public struct OffscreenDemo {
    public static func main() async throws {
        let device = MTLCreateSystemDefaultDevice()!
        var configuration = OffscreenRenderPassConfiguration()
        configuration.colorPixelFormat = .bgra10_xr_srgb
        configuration.device = device
        configuration.update()
        var offscreen = OffscreenDemoRenderPass<OffscreenRenderPassConfiguration>()
        offscreen.setup(configuration: &configuration)

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError()
        }

        commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
            offscreen.draw(configuration: configuration, commandBuffer: commandBuffer)
        }


        let histogram = configuration.targetTexture!.histogram()

        histogram.withEx(type: UInt32.self, count: 4 * 256) { pointer in
            print(Array(pointer))
        }
        let image = await configuration.targetTexture!.cgImage(colorSpace: CGColorSpace(name: CGColorSpace.displayP3))
        let url = URL(filePath: "/tmp/test.jpg")
        try image.write(to: URL(filePath: "/tmp/test.jpg"))
        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.activates = true
        _ = try await NSWorkspace.shared.open(url, configuration: openConfiguration)
    }
}
#endif

