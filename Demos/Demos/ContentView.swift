import SwiftUI
import RenderKit

struct ContentView: View {
    var body: some View {
        //ShaderToyView().metalDevice(MTLCreateSystemDefaultDevice()!)
        SimpleSceneView().metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}
