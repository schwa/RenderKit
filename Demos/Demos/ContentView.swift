import SwiftUI
import RenderKit
import Everything

struct ContentView: View {

    let texture: MTLTexture
    
    init() {
        let url = Bundle.main.resourceURL!.appendingPathComponent("StanfordVolumeData/CThead")
        let volumeData = VolumeData(directoryURL: url, size: [256, 256, 113])
        let load = try! volumeData.load()
        texture = try! load(MTLCreateSystemDefaultDevice()!)
    }
    
    var body: some View {
        SimpleSceneView()
            .metalDevice(MTLCreateSystemDefaultDevice()!)
            .displayLink(DisplayLink2())
    }
}
