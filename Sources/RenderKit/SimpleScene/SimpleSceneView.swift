import SwiftUI
import MetalKit
import ModelIO
import Algorithms
import Observation
import Everything
import SIMDSupport
import SwiftFormats
import SwiftFields
import UniformTypeIdentifiers
import CoreImage
import CoreGraphicsGeometrySupport

public struct SimpleSceneView: View {

    @Environment(\.metalDevice)
    var device

    @State
    var renderPass = SimpleSceneRenderPass()

    #if os(macOS)
    @State
    var isInspectorPresented = true
    #else
    @State
    var isInspectorPresented = false
    #endif

    @State
    var mouselook = false

    @Environment(\.displayLink)
    var displayLink


    public init() {
    }

    public var body: some View {
        ZStack {
            RendererView(renderPass: $renderPass)
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                $renderPass.scene.withUnsafeBinding {
                    MapView(scene: $0)
                    .border(Color.red)
                    .frame(width: 200, height: 200)
                    .padding()
                }
            }
            .overlay(alignment: .bottomLeading) {
                Button(title: mouselook ? "Disable Mouselook (⌘⎋)" : "Enable Mouselook (⌘⎋)", systemImage: mouselook ? "computermouse.fill" : "computermouse") {
                    withAnimation {
                        mouselook.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(mouselook ? Color.mint : Color.yellow)
                .keyboardShortcut(.init(.escape, modifiers: .command))
                .padding()
            }
            .task {
                for await movement in WASDStream(displayLinkPublisher: displayLink) {
                    let target = renderPass.scene!.camera.target
                    let angle = atan2(target.z, target.x) - .pi / 2
                    let rotation = simd_quaternion(angle, [0, -1, 0])
                    let movement = SIMD3<Float>(Float(movement.x), 0, Float(movement.y)) * [-1, 1, -1] * 0.1
                    renderPass.scene!.camera.transform.translation += simd_act(rotation, movement)
                }
            }
            .task {
                for await delta in CapturedMouseStream() {
                    guard mouselook else {
                        continue
                    }
                    guard delta.x != 0 else {
                        continue
                    }
                    renderPass.scene?.camera.heading.degrees += Float(delta.x)
                }
            }
        }
        #if os(macOS)
        .showFrameEditor()
        #endif
        .onAppear {
            do {
                guard let device else {
                    fatalError()
                }

                let cone = try MTKMesh(mesh: MDLMesh(coneWithExtent: [0.5, 1, 0.5], segments: [20, 10], inwardNormals: false, cap: true, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device)
                let sphere = try MTKMesh(mesh: MDLMesh(sphereWithExtent: [0.5, 0.5, 0.5], segments: [20, 10], inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device)
                let capsule = try MTKMesh(mesh: MDLMesh(capsuleWithExtent: [0.25, 1, 0.25], cylinderSegments: [30, 10], hemisphereSegments: 5, inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device)), device: device)

                let meshes = [cone, sphere, capsule]

                let xRange = Array<Float>(stride(from: -2, through: 2, by: 1))
                let zRange = Array<Float>(stride(from: 0, through: -10, by: -1))

                let scene = SimpleScene(
                    camera: Camera(transform: .translation([0, 0, 2]), target: [0, 0, 0], projection: .perspective(.init(fovy: Float(degrees: 90), zClip: 0.1 ... 100))),
                    light: .init(position: .translation([-1, 2, 1]), color: [1, 1, 1], power: 1),
                    ambientLightColor: [0, 0, 0],
                    models:
                        product(xRange, zRange).map { x, z in
                            let hsv: SIMD3<Float> = [Float.random(in: 0...1), 1, 1]
                            let rgba = SIMD4<Float>(hsv.hsv2rgb(), 1.0)
                            return Model(transform: .translation([x, 0, z]), color: rgba, mesh: meshes.randomElement()!)
                        }
                )
                self.renderPass.scene = scene
            }
            catch {
                print(error)
            }
        }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                ValueView(value: false) { isPresentedBinding in
                    Button(title: "Snapshot", systemImage: "camera") {
                        Task {
                            guard let device else {
                                return
                            }
                            let configuration = OffscreenRenderPassConfiguration()
                            configuration.colorPixelFormat = .bgra8Unorm_srgb
                            configuration.depthStencilPixelFormat = .depth16Unorm
                            configuration.device = device
                            configuration.update()
                            renderPass.setup(configuration: configuration)
                            guard let commandQueue = device.makeCommandQueue() else {
                                fatalError()
                            }
                            commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
                                renderPass.draw(configuration: configuration, commandBuffer: commandBuffer)
                            }
                            let cgImage = await configuration.targetTexture!.cgImage(colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB))
                            exportImage = Image(cgImage: cgImage)
                            isPresentedBinding.wrappedValue = true
                        }
                    }
                    .fileExporter(isPresented: isPresentedBinding, item: exportImage, contentTypes: [.png, .jpeg]) { result in
                        exportImage = nil
                    }
                    .fileExporterFilenameLabel("Snapshot")
                }
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            Group {
                $renderPass.scene.withUnsafeBinding {
                    SimpleSceneInspector(scene: $0)
                        .controlSize(.small)
                }
            }
            .inspectorColumnWidth(ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(title: "Show/Hide Inspector", systemImage: "sidebar.trailing") {
                        isInspectorPresented.toggle()
                    }
                }
            }
        }
    }

    @State
    var exportImage: Image?
}

struct SimpleSceneInspector: View {
    @Binding
    var scene: SimpleScene

    let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!

    var body: some View {
        Form {
            Section("Camera") {
                CameraInspector(camera: $scene.camera)
            }
            Section("Light #0") {
                LightInspector(light: $scene.light)
            }
            Section("Ambient Light") {
                ColorPicker("Ambient Light", selection: Binding<CGColor>(simd: $scene.ambientLightColor, colorSpace: colorSpace), supportsOpacity: false)
            }
            Section("Models") {
                Text(String(describing: scene.models.count))
            }
        }
    }

    struct CameraInspector: View {
        @Binding
        var camera: Camera

        var body: some View {
            Section("Transform") {
                TransformEditor(transform: $camera.transform, options: [.hideScale])
                TextField("Heading", value: $camera.heading.degrees, format: .number)
                TextField("Target", value: $camera.target, format: .vector)
            }
            Section("Projection") {
                ProjectionInspector(projection: $camera.projection)
            }
        }
    }

    struct ProjectionInspector: View {
        @State
        var type: Projection.Meta

        @Binding
        var projection: Projection
        
        init(projection: Binding<Projection>) {
            self.type = projection.wrappedValue.meta
            self._projection = projection
        }

        var body: some View {
            Picker("Type", selection: $type) {
                ForEach(Projection.Meta.allCases, id: \.self) { type in
                    Text(describing: type).tag(type)
                }
            }
            .labelsHidden()
            .onChange(of: type) {
                guard type != projection.meta else {
                    return
                }
                switch type {
                case .perspective:
                    projection = .perspective(.init(fovy: .pi / 2, zClip: 0.001 ... 1000))
                case .orthographic:
                    projection = .orthographic(.init(left: -1, right: 1, bottom: -1, top: 1, near: -1, far: 1))
                }
            }
            switch projection {
            case .perspective(let projection):
                let projection = Binding {
                    return projection
                } set: { newValue in
                    self.projection = .perspective(newValue)
                }
//                    let fieldOfView = Binding<SwiftUI.Angle>(get: { .degrees(projection.fovy) }, set: { projection.fovy = $0.radians })
                TextField("FOVY", value: Binding<SwiftUI.Angle>(radians: projection.fovy), format: .angle)
                TextField("Clipping Distance", value: projection.zClip, format: ClosedRangeFormatStyle(substyle: .number))
            case .orthographic(let projection):
                let projection = Binding {
                    return projection
                } set: { newValue in
                    self.projection = .orthographic(newValue)
                }
                TextField("Left", value: projection.left, format: .number)
                TextField("Right", value: projection.right, format: .number)
                TextField("Bottom", value: projection.bottom, format: .number)
                TextField("Top", value: projection.top, format: .number)
                TextField("Near", value: projection.near, format: .number)
                TextField("Far", value: projection.far, format: .number)
            }
        }
    }

    struct LightInspector: View {

        @Binding
        var light: Light

        let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!

        var body: some View {
            LabeledContent("Power") {
                HStack {
                    TextField("Power", value: $light.power, format: .number)
                    .labelsHidden()
                    SliderPopoverButton(value: $light.power)
                }
            }
            ColorPicker("Color", selection: Binding<CGColor>(simd: $light.color, colorSpace: colorSpace), supportsOpacity: false)
            //TextField("Position", value: $light.position, format: .vector)
            TransformEditor(transform: $light.position, options: [.hideScale])
        }
    }
}

struct TransformEditor: View {
    struct Options: OptionSet {
        let rawValue: Int
        static let hideScale = Self(rawValue: 1 << 0)

        static let `default` = Self([])
    }

    @Binding
    var transform: Transform

    let options: Options

    init(transform: Binding<Transform>, options: Options = .default) {
        self._transform = transform
        self.options = options
    }

    var body: some View {
        if !options.contains(.hideScale) {
            TextField("Scale", value: $transform.scale, format: .vector)
        }
        TextField("Rotation", value: $transform.rotation, format: .quaternion)
        TextField("Translation", value: $transform.translation, format: .vector)
    }
}

struct SliderPopoverButton: View {

    @Binding
    var value: Double

    @State
    var isPresented = false

    var body: some View {
        Button(systemImage: "slider.horizontal.2.square") {
            isPresented = true
        }
        .buttonStyle(.borderless)
        .tint(.accentColor)
        .popover(isPresented: $isPresented, content: {
            Slider(value: $value)
            .controlSize(.mini)
            .frame(minWidth: 40)
            .padding()
        })
    }
}

extension SliderPopoverButton {
    init<Value>(value: Binding<Value>) where Value: BinaryFloatingPoint {
        self.init(value: Binding<Double>(value))
    }
}

extension Camera {
    var heading: SIMDSupport.Angle<Float> {
        get {
            let degrees = Angle(from: .zero, to: target.xz).degrees
            return Angle(degrees: degrees)
        }
        set {
            let length = target.length
            target = SIMD3<Float>(xz: SIMD2<Float>(length: length, angle: newValue))
        }
    }
}


public struct DisplayLinkKey: EnvironmentKey {
    public static var defaultValue = DisplayLinkPublisher()
}

public extension EnvironmentValues {
    var displayLink: DisplayLinkPublisher {
        get {
            self[DisplayLinkKey.self]
        }
        set {
            self[DisplayLinkKey.self] = newValue
        }
    }
}

struct MyDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                configuration.label
            }
            .buttonStyle(.borderless)
            if configuration.isExpanded {
                configuration.content
            }
        }
        .padding(4)
    }
}

struct FrameEditorModifier: ViewModifier {

    @State
    var isExpanded: Bool = false

    @State
    var locked: Bool = false

    @State
    var lockedSize: CGSize?

    func body(content: Content) -> some View {
        content
        .frame(width: lockedSize?.width, height: lockedSize?.height)
        .overlay {
            GeometryReader { proxy in
                DisclosureGroup(isExpanded: $isExpanded) {
                    HStack {
                        VStack {
                            if let lockedSize {
                                TextField("Size", value: .constant(lockedSize), format: .size)
                                .foregroundStyle(.black)
                                .frame(maxWidth: 120)
//                                Text("\(proxy.size.width / proxy.size.height, format: .number)")
                            }
                            else {
                                Text("\(proxy.size, format: .size)")
                                Text("\(proxy.size.width / proxy.size.height, format: .number)")
                            }
                        }
                        Button(systemImage: locked ? "lock" : "lock.open") {
                            withAnimation {
                                locked.toggle()
                                lockedSize = locked ? proxy.size : nil
                            }
                        }
                        .buttonStyle(.borderless)
                    }

                } label: {
                    Image(systemName: "rectangle.split.2x2")
                }
                .disclosureGroupStyle(MyDisclosureGroupStyle())
                .foregroundStyle(Color.white)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.mint))
                .padding()
                .frame(alignment: .topLeading)
            }
        }
    }
}

extension View {
    func showFrameEditor() -> some View {
        modifier(FrameEditorModifier())
    }
}

struct MapView: View {
    @Binding
    var scene: SimpleScene

    var body: some View {
        Canvas(opaque: true) { context, size in

            //context.fill(Path(CGRect(size), with: .color(.gray)))

            context.concatenate(.init(translation: [size.width / 2, size.height / 2]))

            context.concatenate(.init(scale: [10, 10]))
            for model in scene.models {
                let position = model.transform.translation.xz
                let colorVector = model.color
                let color = Color(red: Double(colorVector.r), green: Double(colorVector.g), blue: Double(colorVector.b))
                context.fill(Path(ellipseIn: CGRect(center: CGPoint(position), diameter: 1)), with: .color(color))
            }
        }
        .background(.black)



    }
}
