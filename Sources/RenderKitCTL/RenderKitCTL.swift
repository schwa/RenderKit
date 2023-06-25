import RenderKit
import RenderKitDemo
import RenderKitSceneGraph
import RenderKitSupport
import Metal

@main
struct Main {
    static func main() async throws {

        let width = 1024
        let height = 768
        let trace = false

        let device = MTLCreateYoloDevice()
        let model = try DemoModel(device: device)
        let renderer = model.renderer

        let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        outputTextureDescriptor.storageMode = .shared
        outputTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor)!
        outputTexture.label = "Output"

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        let commandQueue = device.makeCommandQueue()!

        var captureScope: MTLCaptureScope?
        if trace {
            let captureManager = MTLCaptureManager.shared()
            captureScope = captureManager.makeCaptureScope(device: device)
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = captureScope
            try captureManager.startCapture(with: captureDescriptor)
            captureScope?.begin()
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!
//        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
//
//        commandEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(width), height: Double(height), znear: 0, zfar: 1))
//        commandEncoder.setCullMode(.back)

        try renderer.render(commandBuffer: commandBuffer)

//        commandEncoder.endEncoding()
        commandBuffer.commit()

        commandBuffer.waitUntilCompleted()

        captureScope?.end()

        let image = outputTexture.betterBetterCGImage

    }
}
