import SwiftUI
import CompositorServices
import ARKit
import RenderKit
import Metal

@main
struct VisionOSDemoApp: App {
    var body: some SwiftUI.Scene {
        ImmersiveSpace {
            CompositorLayer(configuration: MyConfiguration()) { layerRenderer in
                let engine = Engine(renderer: layerRenderer)
                let renderThread = Thread {
                    engine.renderLoop()
                }
                renderThread.name = "Render Thread"
                renderThread.start()
            }
        }
    }
}

struct MyConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities,
                           configuration: inout LayerRenderer.Configuration) {
        let supportsFoveation = capabilities.supportsFoveation
        let supportedLayouts = capabilities.supportedLayouts(options: supportsFoveation ? [.foveationEnabled] : [])
        configuration.layout = supportedLayouts.contains(.layered) ? .layered : .dedicated
        configuration.isFoveationEnabled = supportsFoveation
        configuration.colorFormat = .rgba16Float
    }
}

struct Engine {
    let renderer: LayerRenderer
    let device: MTLDevice

    var appModel: AppModel
    var renderModel: RenderModel

    init(renderer: LayerRenderer) {
        self.renderer = renderer
        self.device = renderer.device
        appModel = try! AppModel(device: self.device)
        renderModel = try! RenderModel(device: self.device, scene: appModel.sceneGraph, graph: appModel.renderGraph)
    }

    func renderLoop() {
        var isRendering = true
        while isRendering {
            autoreleasepool {
                let state = renderer.state
                switch state {
                case .paused:
                    renderer.waitUntilRunning()
                case .running:
                    renderFrame()
                case .invalidated:
                    isRendering = false
                @unknown default:
                    break
                }
            }
        }
    }

    func renderFrame() {
        guard let frame = renderer.queryNextFrame(), let timing = frame.predictTiming() else {
            return
        }
        frame.update {
            //            my_input_state input_state = my_engine_gather_inputs(engine, timing);
            //            my_engine_update_frame(engine, timing, input_state);
        }

        let optimalInputTime = timing.optimalInputTime
        //cp_time_wait_until(cp_frame_timing_get_optimal_input_time(timing));

        frame.submit {
            guard let drawable = frame.queryDrawable() else {
                return
            }

            //drawable.encodePresent(commandBuffer: <#T##MTLCommandBuffer#>)

            let finalTiming = drawable.frameTiming
            let pose = drawable.pose
        }
    }
}

extension LayerRenderer.Frame {
    func update(_ block: () throws -> Void) rethrows {
        startUpdate()
        defer {
            endUpdate()
        }
        try block()
    }

    func submit(_ block: () throws -> Void) rethrows {
        startSubmission()
        defer {
            endSubmission()
        }
        try block()
    }
}
