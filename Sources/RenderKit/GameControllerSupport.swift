import Foundation
import Observation
import SwiftUI
import GameController
import Everything
import AsyncAlgorithms

@Observable
class MovementController {

    var focused: Bool = false

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

    @ObservationIgnored
    var displayLink: DisplayLinkPublisher! = nil

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

    @ObservationIgnored
    var mouse: GCMouse? = nil {
        willSet {
            mouse?.mouseInput?.mouseMovedHandler = nil
        }
        didSet {
            mouse?.handlerQueue = DispatchQueue(label: "Mouse", qos: .userInteractive, attributes: .concurrent)
            mouse?.mouseInput?.mouseMovedHandler = { [weak self] mouse, x, y in
                guard x != 0 || y != 0 else {
                    return
                }
                guard let strongSelf = self else {
                    return
                }
                guard strongSelf.focused == true else {
                    return
                }
                Task(priority: .userInitiated) {
                    await strongSelf.channel.send(.rotation(x))
                }
            }
        }
    }

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

    private func makeEvent() -> [Event] {
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
