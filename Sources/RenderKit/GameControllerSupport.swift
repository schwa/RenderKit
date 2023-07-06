import Foundation
import Observation
import SwiftUI
import GameController
import Everything
import AsyncAlgorithms

// TODO: This needs to be massively cleaned-up and turned into an actor.
// TODO: We need good support for pausing/resuming inputs
// TODO: we need to be able to reliably find devices and handle disconnect/reconnect gracefully
@Observable
class MovementController {

    var focused: Bool = false

    struct Event {
        enum Payload {
            case movement(SIMD3<Float>)
            case rotation(Float)
        }
        var payload: Payload
        var created = CFAbsoluteTimeGetCurrent()

        static func movement(_ movement: SIMD3<Float>) -> Event {
            return .init(payload: .movement(movement))
        }

        static func rotation(_ rotation: Float) -> Event {
            return .init(payload: .rotation(rotation))
        }
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var base: any AsyncIteratorProtocol
        mutating func next() async throws -> Event? {
            return try await base.next() as? Event
        }
    }

    @ObservationIgnored
    var displayLink: DisplayLink! = nil

    @ObservationIgnored
    var controller: GCController? = nil {
        didSet {
            capturedControllerProfile = controller?.physicalInputProfile.capture()
        }
    }
    @ObservationIgnored
    var capturedControllerProfile: GCPhysicalInputProfile? = nil {
        didSet {
            move = capturedControllerProfile?.axes[GCElementKey.leftThumbstickYAxis.rawValue]
            strafe = capturedControllerProfile?.axes[GCElementKey.leftThumbstickXAxis.rawValue]
            turn = capturedControllerProfile?.axes[GCElementKey.rightThumbstickXAxis.rawValue]
        }
    }

    @ObservationIgnored
    var move: GCControllerAxisInput? = nil
    @ObservationIgnored
    var strafe: GCControllerAxisInput? = nil
    @ObservationIgnored
    var turn: GCControllerAxisInput? = nil

    @ObservationIgnored
    let channel = AsyncChannel<Event>()

//    var lastMouseUpdate: TimeInterval = 0

    var mouseMovement: SIMD2<Float> = .zero

    public func disableUIKeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // If we're not focused return everything.
            guard self?.focused == true else {
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

    @ObservationIgnored
    var mouse: GCMouse? = nil {
        willSet {
            mouse?.mouseInput?.mouseMovedHandler = nil
        }
        didSet {
            mouse?.handlerQueue = DispatchQueue(label: "Mouse", qos: .userInteractive)
            mouse?.mouseInput?.mouseMovedHandler = { [weak self] mouseInput, x, y in
                guard x != 0 || y != 0 else {
                    return
                }
                guard let strongSelf = self else {
                    return
                }
                guard strongSelf.focused == true else {
                    return
                }
//                strongSelf.mouseMovement += SIMD2(x, y)
//                Counters.shared.increment(counter: "Mouse (Delta)")
                Task {
                    Counters.shared.increment(counter: "Mouse Moved")
                    await strongSelf.channel.send(.rotation(x))
                }
            }
        }
    }

    init(displayLink: DisplayLink) {
        self.displayLink = displayLink
        Task {
            await keyboard()
        }
    }

    func events() -> AsyncChannel<Event> {
        let notificationCenter = NotificationCenter.default

        let controllerNotificationsTask = Task {
            await withDiscardingTaskGroup { group in
                group.addTask {
                    for await controller in notificationCenter.notifications(named: .GCControllerDidBecomeCurrent).compactMap(\.object).cast(to: GCController.self) {
                        self.controller = controller
                    }
                }
                group.addTask {
                    for await controller in notificationCenter.notifications(named: .GCControllerDidDisconnect).compactMap(\.object).cast(to: GCController.self) {
                        if self.controller === controller {
                            self.controller = nil
                        }
                    }
                }
                group.addTask {
                    for await mouse in notificationCenter.notifications(named: .GCMouseDidConnect).compactMap(\.object).cast(to: GCMouse.self) {
                        self.mouse = mouse
                    }
                }
                group.addTask {
                    for await mouse in notificationCenter.notifications(named: .GCMouseDidDisconnect).compactMap(\.object).cast(to: GCMouse.self) {
                        if self.mouse === mouse {
                            self.mouse = nil
                        }
                    }
                }
            }
        }

        Task() {
            let events = displayLink.events().flatMap { [weak self] _ in
                Counters.shared.increment(counter: "DisplayLink")
                return (self?.makeEvent() ?? []).async
            }
            for await event in events {
                Counters.shared.increment(counter: "Relay")
                await channel.send(event)
            }
            controllerNotificationsTask.cancel()
        }
        return channel
    }

    func keyboard() async {
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
            guard focused else {
                print("Skipping")
                return
            }
            capturedInput.setStateFromPhysicalInput(keyboardInput)
            if leftGUI.value > 0 {
                continue
            }
            var delta = SIMD2<Float>.zero
            if keyW.value > 0 {
                delta += [0, 1]
            }
            if keyS.value > 0 {
                delta += [0, -1]
            }
            if keyA.value > 0 {
                delta += [1, 0]
            }
            if keyD.value > 0 {
                delta += [-1, 0]
            }
            await channel.send(.movement(SIMD3(delta.x, 0, delta.y)))
        }

    }

    private func makeEvent() -> [Event] {
        var allEvents: [Event] = []
        if let controller, let capturedControllerProfile, let move, let strafe, let turn {
            capturedControllerProfile.setStateFromPhysicalInput(controller.physicalInputProfile)
            let movement = SIMD3<Float>(-strafe.value, 0, move.value)
            let rotation = turn.value
            let events = [
                movement != .zero ? Event.movement(movement) : nil,
                rotation != .zero ? Event.rotation(rotation) : nil
            ].compacted()

            Counters.shared.increment(counter: "Poll: GC")

            allEvents += events

        }
        if mouseMovement != .zero {
            Counters.shared.increment(counter: "Poll: Mouse")
            allEvents.append(.rotation(mouseMovement.x))
            mouseMovement = .zero
        }
        return allEvents
    }
}

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
