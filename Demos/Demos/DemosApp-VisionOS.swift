#if os(visionOS)
import SwiftUI
import CompositorServices
import RenderKit

@main
struct DemosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric)
        ImmersiveSpace(id: "ImmersiveSpace") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                try! Renderer(layerRenderer).startRenderLoop()
            }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
#endif
