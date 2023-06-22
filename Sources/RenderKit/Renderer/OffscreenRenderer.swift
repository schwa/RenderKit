// import Everything
// import Foundation
// import Metal
// import simd
//
// open class MetalOffscreenRenderer: MetalRenderer {
//    public let device: MTLDevice
//    public var viewPort: MTLViewport
//    public var colorPixelFormat: MTLPixelFormat
//    public var renderPassDescriptor: MTLRenderPassDescriptor
//    public var colorAttachmentTexture: MTLTexture
//
//    public private(set) var subrenderers: [MetalSubrenderer] = []
//
//    public init(device: MTLDevice? = nil, size: SIMD2<Int> = [1024, 1024]) throws {
//        self.device = device ?? MTLCreateSystemDefaultDevice()!
//        // TODO: HARDCODED
//        viewPort = MTLViewport(originX: 0, originY: 0, width: Double(size.x), height: Double(size.y), znear: -1, zfar: 1)
//        colorPixelFormat = .bgra8Unorm_srgb
//
//        // From What's new In Metal Part 2 - 2016 - extended SRGB - use floating point
//        // Sources: bc6H_rgbFloat, rg11b10Float, rgb9e5Float
//        // Destinations: rg11b10Float, rgba16Float
//        // iOS renders in SRGB, even on P3: BGR10_XR_sRGB, BGRA10_XR_sRGB
//
//        colorAttachmentTexture = self.device.make2DTexture(pixelFormat: colorPixelFormat, size: size, usage: [])
//        colorAttachmentTexture.clear()
//
//        renderPassDescriptor = MTLRenderPassDescriptor()
//        let colorAttachment = MTLRenderPassColorAttachmentDescriptor()
//        colorAttachment.texture = colorAttachmentTexture
//        colorAttachment.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
//
//        renderPassDescriptor.colorAttachments[0] = colorAttachment
//    }
//
//    public func addSubrenderer(_ subrenderer: MetalSubrenderer) {
//        subrenderers.append(subrenderer)
//    }
//
//    public func render() {
//        let commandQueue = device.makeCommandQueue()!
//        let commandBuffer = try! encode(commandQueue: commandQueue, renderPassDescriptor: renderPassDescriptor)
//        commandBuffer.commit()
//    }
// }
