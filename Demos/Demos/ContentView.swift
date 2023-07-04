import SwiftUI
import RenderKit
import Everything

struct ContentView: View {
    var body: some View {
        SimpleSceneView()
            .metalDevice(MTLCreateSystemDefaultDevice()!)
            .displayLink(DisplayLink())

        //        NavigationSplitView {
//            List {
//                NavigationLink("SimpleSceneView") {
//                }
//                NavigationLink("GCView") {
//                    GameControllerView()
//                }
//            }
//        } detail: {
//
//        }


        //ShaderToyView().metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}
