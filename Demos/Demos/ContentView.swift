import SwiftUI
import RenderKit
import Everything

struct ContentView: View {

    @State
    var showUI = true


    var body: some View {
        Group {
            if showUI {
                SimpleSceneView()
                    .metalDevice(MTLCreateSystemDefaultDevice()!)
                    .displayLink(DisplayLink2())
            }
            else {
                ContentUnavailableView("Nothing here", systemImage: "cloud")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(title: "poof", systemImage: "cloud") {
                    showUI = false
                }
            }
        }
    }
}
