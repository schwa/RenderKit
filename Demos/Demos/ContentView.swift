import SwiftUI
import RenderKit
import Everything

struct ContentView: View {

    let texture: MTLTexture
    
    @State
    var scene = SimpleScene.demo()
    
    init() {
        let url = Bundle.main.resourceURL!.appendingPathComponent("StanfordVolumeData/CThead")
        let volumeData = VolumeData(directoryURL: url, size: [256, 256, 113])
        let load = try! volumeData.load()
        texture = try! load(MTLCreateSystemDefaultDevice()!)
    }
    
    var body: some View {
        SimpleSceneView(scene: $scene)
            .metalDevice(MTLCreateSystemDefaultDevice()!)
            .firstPersonInteractive(scene: $scene)
            .displayLink(DisplayLink2())
    }
}
