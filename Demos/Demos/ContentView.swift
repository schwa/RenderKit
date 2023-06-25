import SwiftUI
import Everything
import MetalKit
import Observation
import RenderKitSupport

struct ContentView: View {
    var body: some View {
        MetalView2 { configuration in
            print("setup")
            configuration.colorPixelFormat = .bgra10_xr_srgb
            configuration.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
            configuration.depthStencilPixelFormat = .depth32Float
            configuration.preferredFramesPerSecond = 120
            configuration.enableSetNeedsDisplay = true
        } drawableSizeWillChange: { size in
            print("drawableSizeWillChange", size)
        } draw: { configuration in
            print("drawableSizeWillChange", configuration)
            guard let device = configuration.device else {
                fatalError()
            }
            guard let commandQueue = device.makeCommandQueue() else {
                fatalError()
            }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                fatalError()
            }
            guard let renderPassDescriptor = configuration.currentRenderPassDescriptor else {
                fatalError()
            }
            guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                fatalError()
            }
            renderCommandEncoder.endEncoding()
            guard let currentDrawable = configuration.currentDrawable else {
                fatalError()
            }
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}

// MARK: -

enum RenderKitError: Error {
    case generic(String)
}
