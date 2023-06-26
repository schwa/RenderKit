import SwiftUI
import RenderKit3

struct ContentView: View {
    var body: some View {
        ShaderToyView().metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}
