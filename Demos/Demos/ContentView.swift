import SwiftUI
import RenderKit

struct ContentView: View {
    var body: some View {
        #if os(iOS)
        NavigationView {
            SimpleSceneView().metalDevice(MTLCreateSystemDefaultDevice()!)
        }
        #else
        SimpleSceneView().metalDevice(MTLCreateSystemDefaultDevice()!)
        #endif
        //ShaderToyView().metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}
