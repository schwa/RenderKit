#if !os(visionOS)
import SwiftUI
import RenderKit
import Everything

struct ContentView: View {
    enum Demo: String, CaseIterable, Hashable {
        case simpleScene = "Simple Scene"
        case volumetric = "Volumetric"
    }

    @State
    var scene = SimpleScene.demo()

    @State
    var demo: Demo = .simpleScene

    var body: some View {
        NavigationStack {
            Group {
                List {
                    ForEach(Demo.allCases, id: \.self) { demo in
                        NavigationLink(value: demo) {
                            Text(verbatim: demo.rawValue)
                        }
                    }
                }
                #if os(macOS)
                .frame(maxWidth: 320)
                .padding()
                .frame(maxWidth: .infinity)
                #endif
            }
            .navigationTitle("RenderKit")
            .navigationDestination(for: Demo.self) { demo in
                switch demo {
                case .simpleScene:
                    SimpleSceneView(scene: $scene)
                        .navigationTitle(demo.rawValue)
                case .volumetric:
                    VolumetricView()
                        .navigationTitle(demo.rawValue)
                }
            }
        }
        .metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}

#Preview {
    ContentView()
}
#endif
