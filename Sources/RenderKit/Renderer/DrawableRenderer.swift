import Metal

public class DrawableRenderer: Renderer {
    public static let defaultViewport = MTLViewport(originX: 0, originY: 0, width: 640, height: 480, znear: 0, zfar: 1)

    public let device: MTLDevice
    public var viewport: MTLViewport {
        willSet {
            assert((0 ... 1).contains(viewport.znear))
        }
    }

    public var colorPixelFormat: MTLPixelFormat

    public let commandQueue: MTLCommandQueue
    var subrenderers: [AnySubrenderer] = []
    var cache: [AnySubrenderer.ID: MTLRenderPipelineState] = [:]

    public init(device: MTLDevice? = nil, viewport: MTLViewport = DrawableRenderer.defaultViewport, colorPixelFormat: MTLPixelFormat = .a8Unorm) {
        self.device = device ?? MTLCreateSystemDefaultDevice()!
        self.viewport = viewport
        self.colorPixelFormat = colorPixelFormat
        commandQueue = self.device.makeCommandQueue()!
    }

    public func add<T>(subrenderer: T) where T: Subrenderer {
        subrenderers.append(AnySubrenderer(subrenderer))
    }

    public func remove<T>(subrenderer: T) where T: Subrenderer {
        let subrenderer = AnySubrenderer(subrenderer)
        guard let index = subrenderers.firstIndex(where: { subrenderer.id == $0.id }) else {
            fatalError("No subrenderer found.")
        }
        subrenderers.remove(at: index)

        cache[subrenderer.id] = nil
    }

    public func invalidateCacheFor<T>(subrenderer: T) where T: Subrenderer {
        cache[subrenderer.id] = nil
    }

    public func encode(renderPassDescriptor: MTLRenderPassDescriptor) throws -> MTLCommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Could not make command queue")
        }
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Could not make encoder")
        }
        assert((0 ... 1).contains(viewport.znear))
        // var viewport = self.viewport
        // if viewport.znear < 0 {
        //     //print("viewport.znear(-1) must be between 0.0f and 1.0f")
        //     viewport.znear = 0
        // }
        commandEncoder.setViewport(viewport)
        try encode(commandEncoder: commandEncoder, subrenderers: subrenderers)
        commandEncoder.endEncoding()
        return commandBuffer
    }

    private func encode(commandEncoder: MTLRenderCommandEncoder, subrenderers: [AnySubrenderer]) throws {
        for subrenderer in subrenderers {
            var renderPipelineState: MTLRenderPipelineState! = cache[subrenderer.id]
            if renderPipelineState == nil {
                let pipelineStateDescriptor = try subrenderer.makePipelineDescriptor(renderer: self)
                pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
                renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
                cache[subrenderer.id] = renderPipelineState
            }
            commandEncoder.setRenderPipelineState(renderPipelineState)
            try subrenderer.encode(renderer: self, commandEncoder: commandEncoder)
        }
    }
}
