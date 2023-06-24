import CoreImage
// swiftlint:disable:next duplicate_imports
import CoreImage.CIFilterBuiltins
import Everything
import RenderKit
import RenderKitSupport
import SwiftUI
import Shaders

struct VoronoiNoiseComputeView: View {
    @State
    var image: CGImage?

    @State
    var offset: SIMD2<Float> = [0, 0]

    @State
    var cellSize: SIMD2<Float> = [16, 16]

    @State
    var mode: Int = 1

    var body: some View {
        VStack {
            Text(verbatim: "Mode: \(mode)")
            image.map { Image(cgImage: $0) }

            VStack {
                Picker("Mode", selection: $mode) {
                    Text("0").tag(0)
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .fixedSize()

                Text("Offset.X \(offset.x)")
                Stepper("Offset.x", onIncrement: { offset.x += 1 }, onDecrement: { offset.x -= 1 })
                Slider(value: $offset.x, in: -1000 ... 1000)

                HStack {
                    TextField("Width", value: $cellSize.x, format: .number)
                    TextField("Height", value: $cellSize.y, format: .number)
                }
            }
            .fixedSize()
        }
        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 240, maxHeight: .infinity)
        .onChange(of: mode) {
            update()
        }
        .onChange(of: offset) {
            update()
        }
        .onChange(of: cellSize) {
            update()
        }
        .onAppear(perform: {
            update()
        })
    }

    func update() {
        tryElseLog {
            self.image = try computeHelloWorld(width: 512, height: 512, functionName: "voronoiNoiseCompute", cellSize: cellSize, offset: offset, mode: Int16(mode))
        }
    }
}

func rescale(_ image: CGImage, scale: Float) -> CGImage {
    let filter = CIFilter.bicubicScaleTransform()
    filter.inputImage = CIImage(cgImage: image)
    filter.scale = scale
    filter.aspectRatio = 1.0
    let context = CIContext()
    return context.createCGImage(filter.outputImage!, from: filter.outputImage!.extent)!
}

func computeHelloWorld(width: Int, height: Int, functionName: String, cellSize: SIMD2<Float>, offset: SIMD2<Float>, mode: Int16) throws -> CGImage {
    let device = MTLCreateYoloDevice()
    let library = try device.makeDefaultLibrary(bundle: .renderKitShadersModule)
    let function = library.makeFunction(name: functionName)!

    let outputArray = Array(repeating: SIMD4<Float>(0, 1, 0, 1), count: width * height)
    let outputTexture = device.makeTexture2D(width: width, height: height, pixelFormat: .rgba32Float, storageMode: .shared, usage: .shaderRead | .shaderWrite, pixels: outputArray)

    let start = CFAbsoluteTimeGetCurrent()
    try Compute.compute(function: function) { encoder, workSize in
        withUnsafeBytes(of: cellSize) { buffer in
            encoder.setBytes(buffer.baseAddress!, length: buffer.count, index: VoronoiNoiseComputeBindings.sizeBuffer)
        }
        withUnsafeBytes(of: offset) { buffer in
            encoder.setBytes(buffer.baseAddress!, length: buffer.count, index: VoronoiNoiseComputeBindings.offsetBuffer)
        }
        withUnsafeBytes(of: mode) { buffer in
            encoder.setBytes(buffer.baseAddress!, length: buffer.count, index: VoronoiNoiseComputeBindings.modeBuffer)
        }
        encoder.setTexture(outputTexture, index: VoronoiNoiseComputeBindings.outputTexture)
        workSize.configure(workSize: [width, height, 1])
    }
    let end = CFAbsoluteTimeGetCurrent()
    print("\(#function): \(end - start)")
    return outputTexture.cgImage
}
