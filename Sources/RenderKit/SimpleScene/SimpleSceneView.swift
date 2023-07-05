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
import os

let logger = Logger()

public struct SimpleSceneView: View {

    @Environment(\.metalDevice)
    var device

    @Environment(\.displayLink)
    var displayLink

    @State
    var renderPass = SimpleSceneRenderPass<MetalViewConfiguration>()

    #if os(macOS)
    @State
    var isInspectorPresented = true
    #else
    @State
    var isInspectorPresented = false
    #endif

    @State
    var movementController: MovementController?

    @State
    var exportImage: Image?

    @FocusState
    var renderViewFocused: Bool

    @State
    var label: String?

    public init() {
    }

    public var body: some View {
        ZStack {
            RendererView(renderPass: $renderPass)
            .onAppear {
                guard let displayLink else {
                    fatalError()
                }
                movementController = MovementController(displayLink: displayLink)
            }
            .focusable(interactions: .automatic)
            .focused($renderViewFocused)
            .focusEffectDisabled()
            .defaultFocus($renderViewFocused, true)
//            .ignoresSafeArea()
            .onKeyPress(.escape, action: {
                renderViewFocused = false
                return .handled
            })
            .overlay(alignment: .topTrailing) {
                Group {
                    if renderViewFocused {
                        Image(systemName: "dot.square.fill").foregroundStyle(.selection)
                    }
                    else {
                        Image(systemName: "dot.square").foregroundStyle(.selection)
                    }
                }
                .padding()
            }
            .overlay(alignment: .bottomTrailing) {
                $renderPass.scene.withUnsafeBinding {
                    MapView(scene: $0)
                    .border(Color.red)
                    .frame(width: 200, height: 200)
                    .padding()
                }
            }
            .overlay(alignment: .bottomLeading) {
                GameControllerWidget()
                    .padding()
            }
            .task(priority: .userInitiated) {
                guard let movementController else {
                    fatalError()
                }
                // .throttle(for: .seconds(1/60), latest: true)
                for await event in movementController.events() {
                    Counters.shared.increment(counter: "Consumption")

//                    let delta = CFAbsoluteTimeGetCurrent() - event.created
//                    let change = delta - last
//                    last = delta
//                    logger.debug("\(delta) \(change)")

                    switch event.payload {
                    case .movement(let movement):
                        let target = renderPass.scene!.camera.target
                        let angle = atan2(target.z, target.x) - .pi / 2
                        let rotation = simd_quaternion(angle, [0, -1, 0])
                        renderPass.scene!.camera.transform.translation += simd_act(rotation, movement * 0.1)
                    case .rotation(let rotation):
                        renderPass.scene?.camera.heading.degrees += Float(rotation * 2)
                    }
                }
            }
            .task(priority: .userInitiated) {
                return
                guard let displayLink else {
                    fatalError()
                }
                // TODO: Move to MovementController
                for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
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

                for await _ in displayLink.events() {
                    guard renderViewFocused else {
                        print("Skipping")
                        return
                    }
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
        }
        #if os(macOS)
        .onAppear {
            // Move to MovementController
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // If we're not focused return everything.
                guard renderViewFocused else {
                    return event
                }
                // If a modifier is down
                guard event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty else {
                    return event
                }
                // If we're not a WASD key
                guard ["w", "a", "s", "d"].contains(event.characters) else {
                    return event
                }
                // Consume the key
                return nil
            }
        }
        #endif
        .onChange(of: renderViewFocused) {
            movementController?.focused = renderViewFocused
        }
        #if os(macOS)
        .showFrameEditor()
        #endif
        .onAppear {
            do {
                guard let device else {
                    fatalError()
                }
                self.renderPass.scene = try .demo(device: device)
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
//                            // Move this logic out
//                            guard let device else {
//                                return
//                            }
//                            var configuration = OffscreenRenderPassConfiguration()
//                            configuration.colorPixelFormat = .bgra8Unorm_srgb
//                            configuration.depthStencilPixelFormat = .depth16Unorm
//                            configuration.device = device
//                            configuration.update()
//                            renderPass.setup(configuration: configuration)
//                            guard let commandQueue = device.makeCommandQueue() else {
//                                fatalError()
//                            }
//                            commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
//                                renderPass.draw(configuration: configuration, commandBuffer: commandBuffer)
//                            }
//                            let cgImage = await configuration.targetTexture!.cgImage(colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB))
//                            exportImage = Image(cgImage: cgImage)
//                            isPresentedBinding.wrappedValue = true
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
            MyTabView(renderPass: $renderPass)
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
                let viewCone = Path.arc(center: cameraPosition * scale, radius: 4 * scale, midAngle: .radians(Double(scene.camera.heading.radians)), width: .radians(Double(perspective.fovy.radians)))
//                context.fill(viewCone, with: .radialGradient(Gradient(colors: [.white.opacity(0.5), .white.opacity(0.0)]), center: cameraPosition * scale, startRadius: 0, endRadius: 4 * scale))
                context.stroke(viewCone, with: .color(.white))

            }

            var cameraImage = context.resolve(Image(systemName: "camera.circle.fill"))
            cameraImage.shading = .color(.mint)
            context.draw(cameraImage, at: cameraPosition * scale, anchor: .center)

            let targetPosition = cameraPosition + CGPoint(scene.camera.target.xz)
            var targetImage = context.resolve(Image(systemName: "scope"))
            targetImage.shading = .color(.white)
            context.draw(targetImage, at: targetPosition * scale, anchor: .center)

        }
        .background(.black)
    }
}

//extension RenderPass {
//    mutating func snapshot(device: MTLDevice) async throws -> CGImage {
//        let configuration = OffscreenRenderPassConfiguration()
//        configuration.colorPixelFormat = .bgra8Unorm_srgb
//        configuration.depthStencilPixelFormat = .depth16Unorm
//        configuration.device = device
//        configuration.update()
//        self.setup(configuration: configuration)
//        guard let commandQueue = device.makeCommandQueue() else {
//            fatalError()
//        }
//        commandQueue.withCommandBuffer(waitAfterCommit: true) { commandBuffer in
//            self.draw(configuration: configuration, commandBuffer: commandBuffer)
//        }
//        let cgImage = await configuration.targetTexture!.cgImage(colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB))
//        return cgImage
//    }
//}

struct MyTabView: View {

    enum Tab: Hashable {
        case inspector
        case counters
    }

    @State
    var tab: Tab = .inspector

    @Binding
    var renderPass: SimpleSceneRenderPass<MetalViewConfiguration>

    var body: some View {
        VStack {
            Picker("Picker", selection: $tab) {
                Image(systemName: "slider.horizontal.3").tag(Tab.inspector)
                Image(systemName: "tablecells").tag(Tab.counters)
            }
            .labelsHidden()
            .fixedSize()
            .pickerStyle(.palette)
            Divider()
            switch tab {
            case .inspector:
                Group {
                    $renderPass.scene.withUnsafeBinding {
                        SimpleSceneInspector(scene: $0)
                            .controlSize(.small)
                    }
                }
            case .counters:
                CountersView()
            }
        }
    }
}
