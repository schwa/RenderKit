import Foundation
import RenderKit3
import Metal
import AppKit
import Everything
import MetalPerformanceShaders

@main
struct Main {
    static func main() async throws {
        let configuration = OffscreenDemo.Configuration()
        configuration.colorPixelFormat = .bgra10_xr
        configuration.device = MTLCreateSystemDefaultDevice()
        configuration.update()
        var offscreen = OffscreenDemo()
        offscreen.setup(configuration: configuration)
        offscreen.draw(configuration: configuration)

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
