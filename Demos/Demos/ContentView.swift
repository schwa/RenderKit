#if !os(visionOS)
import SwiftUI
import RenderKit
import Everything

struct ContentView: View {
    enum Demo: String, CaseIterable, Hashable {
        case scene = "Simple Scene"
        case volumetric = "Volumetric"
    }

    @State
    var scene = SimpleScene.demo()

    @State
    var demo: Demo = .scene

    var body: some View {
        Group {
            switch demo {
            case .scene:
                SimpleSceneView(scene: $scene)
                    .metalDevice(MTLCreateSystemDefaultDevice()!)
                    .firstPersonInteractive(scene: $scene)
                    .displayLink(DisplayLink2())
            case .volumetric:
                VolumeView()
                    .metalDevice(MTLCreateSystemDefaultDevice()!)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker(selection: $demo, label: Text("Demo")) {
                    ForEach(Demo.allCases, id: \.self) { demo in
                        Text("\(demo.rawValue)").tag(demo)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
#endif
