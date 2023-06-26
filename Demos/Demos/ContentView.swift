import SwiftUI
import Everything
import MetalKit
import Observation
import RenderKitSupport

struct ContentView: View {
    var body: some View {
        ShaderToyView().metalDevice(MTLCreateSystemDefaultDevice()!)
    }
}
