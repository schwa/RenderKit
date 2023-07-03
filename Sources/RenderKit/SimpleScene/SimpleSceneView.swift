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
import GameController
import AsyncAlgorithms
import Combine

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

    @State
    var movementController = MovementController()

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
                HStack {
                    GameControllerWidget()

#if os(macOS)
//                    Button(title: mouselook ? "Disable Mouselook (⌘⎋)" : "Enable Mouselook (⌘⎋)", systemImage: mouselook ? "computermouse.fill" : "computermouse") {
//                        withAnimation {
//                            mouselook.toggle()
//                        }
//                    }
//                    .keyboardShortcut(.init(.escape, modifiers: .command))
//                    .buttonStyle(.borderedProminent)
#endif
                }
//                .tint(mouselook ? Color.mint : Color.yellow)
                .padding()
            }
            .task(priority: .userInitiated) {
//                var controller = GCController.current
                for await event in movementController.events().debounce(for: .seconds(1/60)) {
                    switch event {

                    case .movement(let movement):
                        let target = renderPass.scene!.camera.target
                        let angle = atan2(target.z, target.x) - .pi / 2
                        let rotation = simd_quaternion(angle, [0, -1, 0])
                        renderPass.scene!.camera.transform.translation += simd_act(rotation, movement * 0.1)
                    case .rotation(let rotation):
                        renderPass.scene?.camera.heading.degrees += Float(rotation * 2)
                    }

                }


//                if let controller, let gamePad = controller.extendedGamepad {
//                    let snapshot = gamePad.capture()
//                    let turning = snapshot.rightThumbstick.xAxis
//                    let leftRight = snapshot.leftThumbstick.xAxis
//                    let forwardsReverse = snapshot.leftThumbstick.yAxis
//                    for await _ in displayLink.values {
//                        snapshot.setStateFromPhysicalInput(gamePad)
//                        var movement = SIMD3<Float>.zero
//                        movement.x = -leftRight.value
//                        movement.z = forwardsReverse.value
//                        let target = renderPass.scene!.camera.target
//                        let angle = atan2(target.z, target.x) - .pi / 2
//                        let rotation = simd_quaternion(angle, [0, -1, 0])
//                        renderPass.scene!.camera.transform.translation += simd_act(rotation, movement * 0.1)
//                        renderPass.scene?.camera.heading.degrees += Float(turning.value * 2)
//                    }
//                }
            }
            .task(priority: .userInitiated) {
                for await notification in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
                    break
                }

                guard let keyboard = GCKeyboard.coalesced, let keyboardInput = keyboard.keyboardInput else {
                    fatalError()
                }

                let capturedInput = keyboardInput.capture()
                let leftGUI = capturedInput.button(forKeyCode: .leftGUI)!
                let keyW = capturedInput.button(forKeyCode: .keyW)!
                let keyA = capturedInput.button(forKeyCode: .keyA)!
                let keyS = capturedInput.button(forKeyCode: .keyS)!
                let keyD = capturedInput.button(forKeyCode: .keyD)!

                for await _ in displayLink.values {
                    capturedInput.setStateFromPhysicalInput(keyboardInput)
                    if leftGUI.value > 0 {
                        continue
                    }
                    var delta = SIMD2<Float>.zero
                    if keyW.value > 0 {
                        delta += [0, -1]
                    }
                    if keyS.value > 0 {
                        delta += [0, 1]
                    }
                    if keyA.value > 0 {
                        delta += [-1, 0]
                    }
                    if keyD.value > 0 {
                        delta += [1, 0]
                    }
                    let target = renderPass.scene!.camera.target
                    let angle = atan2(target.z, target.x) - .pi / 2
                    let rotation = simd_quaternion(angle, [0, -1, 0])
                    let movement = SIMD3<Float>(delta[0], 0, delta[1]) * [-1, 1, -1] * 0.1
                    renderPass.scene!.camera.transform.translation += simd_act(rotation, movement)
                }
            }

            //            .task {
//                for await movement in WASDStream(displayLinkPublisher: displayLink) {
//                    let target = renderPass.scene!.camera.target
//                    let angle = atan2(target.z, target.x) - .pi / 2
//                    let rotation = simd_quaternion(angle, [0, -1, 0])
//                    let movement = SIMD3<Float>(Float(movement.x), 0, Float(movement.y)) * [-1, 1, -1] * 0.1
//                    renderPass.scene!.camera.transform.translation += simd_act(rotation, movement)
//                }
//            }
#if os(macOS)
            .task(priority: .userInitiated) {
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
            #endif
        }
        #if os(macOS)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty {
                    return nil
                }
                else {
                    return event
                }
            }
        }
        #endif
        .focusable(interactions: .automatic)
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
                    camera: Camera(transform: .translation([0, 0, 2]), target: [0, 0, -1], projection: .perspective(.init(fovy: Float(degrees: 90), zClip: 0.1 ... 100))),
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

    let scale: CGFloat = 10

    var body: some View {
        Canvas(opaque: true) { context, size in
            context.concatenate(.init(translation: [size.width / 2, size.height / 2]))

            for model in scene.models {
                let position = CGPoint(model.transform.translation.xz)
                let colorVector = model.color
                let color = Color(red: Double(colorVector.r), green: Double(colorVector.g), blue: Double(colorVector.b))
                context.fill(Path(ellipseIn: CGRect(center: position * scale, diameter: 1 * scale)), with: .color(color.opacity(0.5)))
            }

            let cameraPosition = CGPoint(scene.camera.transform.translation.xz)

            if case let .perspective(perspective) = scene.camera.projection {
                let viewCone = Path.arc(center: cameraPosition * scale, radius: 4 * scale, midAngle: .radians(Double(scene.camera.heading.radians)), width: .radians(Double(perspective.fovy)))
                context.fill(viewCone, with: .radialGradient(Gradient(colors: [.white.opacity(0.5), .white.opacity(0.0)]), center: cameraPosition * scale, startRadius: 0, endRadius: 4 * scale))
                context.stroke(viewCone, with: .color(.white))

            }

            var cameraImage = context.resolve(Image(systemName: "camera.circle.fill"))
            cameraImage.shading = .color(.mint)
            context.draw(cameraImage, at: cameraPosition * scale, anchor: .center)

            var targetPosition = cameraPosition + CGPoint(scene.camera.target.xz)
            var targetImage = context.resolve(Image(systemName: "scope"))
            targetImage.shading = .color(.white)
            context.draw(targetImage, at: targetPosition * scale, anchor: .center)

        }
        .background(.black)
    }
}

extension CGSize {
    static func / (lhs: CGFloat, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs / rhs.width, height: lhs / rhs.height)
    }
}

extension Path {
    static func arc(center: CGPoint, radius: CGFloat, midAngle: SwiftUI.Angle, width: SwiftUI.Angle) -> Path {
        Path { path in
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: midAngle - width / 2, endAngle: midAngle + width / 2, clockwise: false)
            path.closeSubpath()
        }
    }
}

struct GameControllerWidget: View {

    @Observable
    class Model {
        var scanning = false

        struct DeviceBox: Hashable, Identifiable {
            var id: ObjectIdentifier {
                return ObjectIdentifier(device)
            }

            static func == (lhs: GameControllerWidget.Model.DeviceBox, rhs: GameControllerWidget.Model.DeviceBox) -> Bool {
                lhs.device === rhs.device
            }

            func hash(into hasher: inout Hasher) {
                id.hash(into: &hasher)
            }

            let device: any GCDevice
        }

        var devices: Set<DeviceBox> = []

#if os(iOS)
        var virtualController: GCVirtualController? = nil
        // Temporary workaround for FB12509166
        @ObservationIgnored
        var _virtualController: GCVirtualController? = nil
#endif

        init() {
            devices.formUnion(GCController.controllers().map(DeviceBox.init))
            Task {
                for await notification in NotificationCenter.default.notifications(named: .GCControllerDidConnect) {
                    guard let controller = notification.object as? GCDevice else {
                        return
                    }
                    devices.insert(DeviceBox(device: controller))
                }
            }
            Task {
                for await notification in NotificationCenter.default.notifications(named: .GCControllerDidDisconnect) {
                    guard let controller = notification.object as? GCDevice else {
                        return
                    }
                    devices.remove(DeviceBox(device: controller))
                }
            }
            Task {
                for await notification in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
                    guard let controller = notification.object as? GCDevice else {
                        return
                    }
                    devices.insert(DeviceBox(device: controller))
                }
            }
            Task {
                for await notification in NotificationCenter.default.notifications(named: .GCKeyboardDidDisconnect) {
                    guard let controller = notification.object as? GCDevice else {
                        return
                    }
                    devices.remove(DeviceBox(device: controller))
                }
            }
            Task {
                for await notification in NotificationCenter.default.notifications(named: .GCMouseDidConnect) {
                    guard let controller = notification.object as? GCDevice else {
                        return
                    }
                    devices.insert(DeviceBox(device: controller))
                }
            }
            Task {
                for await notification in NotificationCenter.default.notifications(named: .GCMouseDidDisconnect) {
                    guard let controller = notification.object as? GCDevice else {
                        return
                    }
                    devices.remove(DeviceBox(device: controller))
                }
            }
            startDiscovery()
        }

        func startDiscovery() {
            guard scanning == false else {
                return
            }
            scanning = true
            GCController.startWirelessControllerDiscovery { [weak self] in
                self?.scanning = false
            }
        }

        func stopDiscovery() {
            GCController.stopWirelessControllerDiscovery()
            scanning = false
        }
    }

    @State
    var model = Model()

    var body: some View {
        HStack {
//            Image(systemName: "gamecontroller").symbolEffect(.pulse.byLayer)
//                .symbolRenderingMode(.palette)
//                .foregroundStyle(.red, .green, .blue)
//                .background(.white)
            Menu{
                if model.scanning == false {
                    Button("Start Scanning") {
                        model.startDiscovery()
                    }
                }
                else {
                    Button("Stop Scanning") {
                        model.stopDiscovery()
                    }
                }
                #if os(iOS)
                Divider()
                if model.virtualController != nil {
                    Button("Disable Touch Controller") {
                        model.virtualController?.disconnect()
                        model.virtualController = nil
                    }
                }
                else {
                    Button("Enable Touch Controller") {
                        Task {
                            let configuration = GCVirtualController.Configuration()
                            configuration.elements = [
                                GCInputLeftThumbstick, GCInputRightThumbstick, GCInputLeftShoulder, GCInputRightShoulder,
                                //                        GCInputButtonA,
                                //                        GCInputButtonB,
                                //                        GCInputButtonX,
                                //                        GCInputButtonY,
                                //GCInputDirectionPad,
                                //                        GCInputLeftTrigger,
                                //                        GCInputRightTrigger
                            ]
                            let virtualController = GCVirtualController(configuration: configuration)
                            try! await virtualController.connect()
                            model.virtualController = virtualController
                        }
                    }
                }
                #endif
                if !model.devices.isEmpty {
                    Divider()
                    ForEach(Array(model.devices), id: \.self) { box in
                        Label {
                            let isCurrent = (box.device as? GCController) === GCController.current
                            Text("\(box.device.productCategory) / \(box.device.vendorName ?? "unknown controller")") + (isCurrent ? Text(" (current)") : Text(""))
                        } icon: {
                            box.device.sfSymbolName.map { Image(systemName: $0) } ?? Image(systemName: "questionmark.square.dashed")
                        }
                    }
                }

//                Button(action: {}, label: {
//                    Image(systemName: "gamecontroller").symbolEffect(.pulse.byLayer)
//                })
            }
        label: {
            Label(
                title: { Text("Game Controller") },
                icon: {
                    if model.devices.isEmpty {
                        Image(systemName: "gamecontroller")
                    }
                    else {
                        Image(systemName: "gamecontroller.fill")
                    }
                }
            )
            .labelStyle(.iconOnly)
        }
        .fixedSize()
        .backgroundStyle(Color.yellow)
        }
    }
}

extension GCDevice {
    var sfSymbolName: String? {
        switch self {
        case _ as GCController:
            return "gamecontroller"
        case _ as GCKeyboard:
            return "keyboard"
        case _ as GCMouse:
            return "mouse"
        default:
            return nil
        }
    }
}


@Observable
class MovementController {
    init(displayLink: DisplayLinkPublisher = .init()) {
        self.displayLink = displayLink
    }

    enum Event {
        case movement(SIMD3<Float>)
        case rotation(Float)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var base: any AsyncIteratorProtocol
        mutating func next() async throws -> Event? {
            return try await base.next() as? Event
        }
    }

    var displayLink: DisplayLinkPublisher! = nil

    var controller: GCController? = nil {
        didSet {
            capturedControllerProfile = controller?.physicalInputProfile.capture()
        }
    }
    var capturedControllerProfile: GCPhysicalInputProfile? = nil {
        didSet {
            move = capturedControllerProfile?.axes[GCElementKey.leftThumbstickYAxis.rawValue]
            strafe = capturedControllerProfile?.axes[GCElementKey.leftThumbstickXAxis.rawValue]
            turn = capturedControllerProfile?.axes[GCElementKey.rightThumbstickXAxis.rawValue]
        }
    }

    var move: GCControllerAxisInput? = nil
    var strafe: GCControllerAxisInput? = nil
    var turn: GCControllerAxisInput? = nil

    var mouse: GCMouse? = nil {
        willSet {
            mouse?.mouseInput?.mouseMovedHandler = nil
        }
        didSet {
            mouse?.handlerQueue = DispatchQueue(label: "Mouse", qos: .userInteractive, attributes: .concurrent)
            mouse?.mouseInput?.mouseMovedHandler = { [weak self] mouse, x, y in
                guard let strongSelf = self else {
                    return
                }
                Task(priority: .userInitiated) {
                    await strongSelf.channel.send(.rotation(x))
                }
            }
        }
    }

    let channel = AsyncChannel<Event>()


    func events() -> AsyncChannel<Event> {
        let notificationCenter = NotificationCenter.default
        Task {
            for await controller in notificationCenter.notifications(named: .GCControllerDidBecomeCurrent).map(\.object).cast(to: GCController.self) {
                self.controller = controller
            }
        }
        Task {
            for await controller in notificationCenter.notifications(named: .GCControllerDidDisconnect).map(\.object).cast(to: GCController.self) {
                if self.controller === controller {
                    self.controller = nil
                }
            }
        }
        Task {
            for await mouse in notificationCenter.notifications(named: .GCMouseDidConnect).map(\.object).cast(to: GCMouse.self) {
                self.mouse = mouse
            }
        }
        Task {
            for await mouse in notificationCenter.notifications(named: .GCMouseDidDisconnect).map(\.object).cast(to: GCMouse.self) {
                if self.mouse === mouse {
                    self.mouse = nil
                }
            }
        }

        Task(priority: .userInitiated) {
            let events = displayLink.values.flatMap { [weak self] _ in
                return (self?.makeEvent() ?? []).async
            }
            for await event in events {
                await channel.send(event)
            }

        }
        return channel
    }

    func makeEvent() -> [Event] {
        var events: [Event] = []
        if let controller, let capturedControllerProfile, let move, let strafe, let turn {
            capturedControllerProfile.setStateFromPhysicalInput(controller.physicalInputProfile)
            let movement = SIMD3<Float>(-strafe.value, 0, move.value)
            let rotation = turn.value
            events.append(contentsOf: [
                movement != .zero ? Event.movement(movement) : nil,
                rotation != .zero ? Event.rotation(rotation) : nil
            ].compacted())
        }
        return events
    }
}

//["Direction Pad X Axis", "Button A", "Right Thumbstick Down", "Direction Pad Down", "Button X", "Right Thumbstick X Axis", "Left Thumbstick Y Axis", "Direction Pad Up", "Right Trigger", "Left Thumbstick Up", "Button B", "Left Thumbstick Down", "Left Thumbstick Right", "Left Shoulder", "Direction Pad Left", "Direction Pad", "Direction Pad Y Axis", "Left Thumbstick Left", "Right Thumbstick Right", "Button Menu", "Left Thumbstick", "Right Shoulder", "Direction Pad Right", "Right Thumbstick", "Right Thumbstick Up", "Left Thumbstick X Axis", "Right Thumbstick Y Axis", "Left Trigger", "Button Y", "Right Thumbstick Left"]
//["Left Thumbstick X Axis", "Right Thumbstick Up", "Left Thumbstick Y Axis", "Right Shoulder", "Right Trigger", "Right Thumbstick X Axis", "Direction Pad Down", "Left Thumbstick Up", "Direction Pad Left", "Left Thumbstick", "Direction Pad Y Axis", "Left Trigger", "Right Thumbstick", "Left Thumbstick Right", "Button Y", "Right Thumbstick Y Axis", "Right Thumbstick Down", "Right Thumbstick Left", "Button X", "Button B", "Direction Pad", "Right Thumbstick Right", "Direction Pad Right", "Button Menu", "Direction Pad Up", "Button A", "Left Thumbstick Left", "Direction Pad X Axis", "Left Shoulder", "Left Thumbstick Down"]
//["Left Thumbstick Down", "Left Trigger", "Button X", "Right Thumbstick Left", "Right Thumbstick Right", "Left Thumbstick Up", "Button Y", "Right Shoulder", "Direction Pad Down", "Left Thumbstick Left", "Right Trigger", "Direction Pad Left", "Button B", "Direction Pad Right", "Left Thumbstick Right", "Button Menu", "Right Thumbstick Up", "Direction Pad Up", "Right Thumbstick Down", "Left Shoulder", "Button A"]
//["Left Thumbstick X Axis", "Direction Pad Y Axis", "Direction Pad X Axis", "Right Thumbstick X Axis", "Left Thumbstick Y Axis", "Right Thumbstick Y Axis"]
//["Right Thumbstick", "Direction Pad", "Left Thumbstick"]

enum GCElementKey: String, CaseIterable {
    case buttonA = "Button A"
    case buttonB = "Button B"
    case buttonMenu = "Button Menu"
    case buttonX = "Button X"
    case buttonY = "Button Y"
    case directionPad = "Direction Pad"
    case directionPadDown = "Direction Pad Down"
    case directionPadLeft = "Direction Pad Left"
    case directionPadRight = "Direction Pad Right"
    case directionPadUp = "Direction Pad Up"
    case directionPadXAxis = "Direction Pad X Axis"
    case directionPadYAxis = "Direction Pad Y Axis"
    case leftShoulder = "Left Shoulder"
    case leftThumbstick = "Left Thumbstick"
    case leftThumbstickDown = "Left Thumbstick Down"
    case leftThumbstickLeft = "Left Thumbstick Left"
    case leftThumbstickRight = "Left Thumbstick Right"
    case leftThumbstickUp = "Left Thumbstick Up"
    case leftThumbstickXAxis = "Left Thumbstick X Axis"
    case leftThumbstickYAxis = "Left Thumbstick Y Axis"
    case leftTrigger = "Left Trigger"
    case rightShoulder = "Right Shoulder"
    case rightThumbstick = "Right Thumbstick"
    case rightThumbstickDown = "Right Thumbstick Down"
    case rightThumbstickLeft = "Right Thumbstick Left"
    case rightThumbstickRight = "Right Thumbstick Right"
    case rightThumbstickUp = "Right Thumbstick Up"
    case rightThumbstickXAxis = "Right Thumbstick X Axis"
    case rightThumbstickYAxis = "Right Thumbstick Y Axis"
    case rightTrigger = "Right Trigger"
}

extension AsyncSequence {
    func cast <T>(to: T.Type) -> AsyncCompactMapSequence<Self, T?> {
        compactMap { $0 as? T }
    }
}
