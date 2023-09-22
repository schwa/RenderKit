#if !os(visionOS)
import SwiftUI
import RenderKit
import Everything

struct ContentView: View {
    @State
    var scene = SimpleScene.demo()

    init() {
    }

    var body: some View {
        if false {
            SimpleSceneView(scene: $scene)
                .metalDevice(MTLCreateSystemDefaultDevice()!)
                .firstPersonInteractive(scene: $scene)
                .displayLink(DisplayLink2())
        }
        else {
            VolumeView()
                .metalDevice(MTLCreateSystemDefaultDevice()!)
        }
    }
}
#endif
