import SwiftUI
import RenderKit

struct ContentView: View {
    var body: some View {
//        NavigationSplitView {
//            List {
//                NavigationLink("SimpleSceneView") {
                    SimpleSceneView().metalDevice(MTLCreateSystemDefaultDevice()!)
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
