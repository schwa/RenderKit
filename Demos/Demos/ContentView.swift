import SwiftUI
import RenderKit

struct ContentView: View {
    var body: some View {


        NavigationView {
            SimpleSceneView().metalDevice(MTLCreateSystemDefaultDevice()!)
        }
        //ShaderToyView().metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}
