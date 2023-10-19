#if !os(visionOS)
import SwiftUI
import RenderKit
import Everything

struct ContentView: View {
    enum Demo: String, CaseIterable, Hashable {
        case simpleScene = "Simple Scene"
        case simpleSceneExtended = "Simple Scene (Extended)"
        case volumetric = "Volumetric"
//        case gltf = "GLTF"
        case simulationSUI = "simulationSUI"
        case screenSpaceDemoView = "ScreenSpaceDemoView"
    }

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
                    CoreSimpleSceneView()
                        .navigationTitle(demo.rawValue)
                case .simpleSceneExtended:
                    SimpleSceneView()
                        .navigationTitle(demo.rawValue)
                case .volumetric:
                    VolumetricView()
                        .navigationTitle(demo.rawValue)
//                case .gltf:
//                    GLTFView()
//                        .navigationTitle(demo.rawValue)
                case .simulationSUI:
                    SimulationView()
                case .screenSpaceDemoView:
                    ScreenSpaceDemoView()
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
