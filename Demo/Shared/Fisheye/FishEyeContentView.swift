import SwiftUI

struct FishEyeContentView: View {

    @State
    var image: Image?

    @State
    var debug = false

    @State
    var value: Float = 0

    @State
    var uniforms = Uniforms(lerp: 1, phi1: 0, phi0: 0, lambda0: 0, r: 1 / .pi * 2, scale: 1.0)

    let images = [
        "3D Capture",
        "3D Capture-Left",
        "big-gallery-005worldmap",
    ]

    @State
    var imageSelection: String = "3D Capture"

    var body: some View {
        VStack {
            #if os(macOS)
            OfflineMetalView(image: imageSelection, debug: debug, uniforms: uniforms)
            #endif
            Form {
                Picker("Image", selection: $imageSelection) {
                    ForEach(images, id: \.self) { image in
                        Text(verbatim: image).tag(image)
                    }
                }
                Toggle("Debug", isOn: $debug)
                TextField("r", value: $uniforms.r, format: .number)
                TextField("phi0", value: $uniforms.phi0, format: .number)
                TextField("phi1", value: $uniforms.phi1, format: .number)
                TextField("lambda0", value: $uniforms.lambda0, format: .number)
                Slider(value: Binding(other: $uniforms.lerp), in: 0.0 ... 1.0, label: { Text("Lerp") })
                Slider(value: Binding(other: $uniforms.scale), in: -2.0 ... 2.0, label: { Text("Scale") })
            }
            .frame(maxWidth: 320)
        }
        .padding()
    }
}

#if os(macOS)
struct OfflineMetalView: View {

    let sourceImage: Image
    let outputImage: Image

    init(image: String, debug: Bool, uniforms: Uniforms) {
        let nsSourceImage = NSImage(named: image)!
        let cgImage = nsSourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let result = try! FishEyeRemoval(trace: debug).main(cgImage: cgImage, uniforms: uniforms)
        let nsImage = NSImage(cgImage: result, size: CGSize(width: result.width, height: result.height))
        sourceImage = Image(nsImage: nsSourceImage)
        outputImage = Image(nsImage: nsImage)
    }

    var body: some View {
        VStack {
            sourceImage.resizable().scaledToFit().border(Color.green)
            outputImage.resizable().scaledToFit().border(Color.red)
        }
    }

}
#endif
