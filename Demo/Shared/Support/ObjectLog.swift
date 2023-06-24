import Everything
import Foundation
import simd
import SwiftUI

@MainActor
class ObjectLog {
    static let shared = ObjectLog()

    private var labels: [String] = []
    private var current: [String: Event] = [:]
    private var callbacks: [([Event]) -> Void] = []

    struct Event: @unchecked Sendable {
        let date: Date
        let label: String
        let value: Any
    }

    init() {
    }

    func emit(_ value: some Sendable, for label: String) {
        if current[label] == nil {
            labels.append(label)
        }
        current[label] = Event(date: Date(), label: label, value: value)
        for callback in callbacks {
            callback(snapshot())
        }
    }

    private func snapshot() -> [Event] {
        labels.map { current[$0]! }
    }

    func addCallback(_ callback: @escaping ([Event]) -> Void) {
        callbacks.append(callback)
    }
}

@MainActor
func emit(_ value: some Sendable, for label: String) {
    ObjectLog.shared.emit(value, for: label)
}

// MARK: -

struct ObjectLogView: View {
    @State
    @MainActor
    var events: [ObjectLog.Event] = []

    @State
    @MainActor
    var frozen = false

    var body: some View {
        VStack {
            Toggle("Frozen", isOn: $frozen)
                .onAppear {
                    ObjectLog.shared.addCallback {
                        update(events: $0)
                    }
                }
            List(events.indices, id: \.self) { index in
                let event = events[index]
                EventView(event: event)
            }
        }
    }

    @MainActor
    func update(events: [ObjectLog.Event]) {
        if !frozen {
            self.events = events
        }
    }
}

struct EventView: View {
    enum Mode {
        case native
        case description
        case debugDescription
    }

    let event: ObjectLog.Event

    @State
    var mode: Mode = .native

    @State
    var nativeEnabled = true

    init(event: ObjectLog.Event) {
        self.event = event
    }

    var body: some View {
        GroupBox("\(event.label)") {
//            Text(event.date, format: .dateTime)
//            Text(verbatim: "\(type(of: event.value))")
            Picker("Mode", selection: $mode) {
                if nativeEnabled {
                    Text("Native").tag(Mode.native)
                }
                Text("Description").tag(Mode.description)
                Text("Debug Description").tag(Mode.debugDescription)
            }
            .fixedSize()
            .controlSize(.mini)

            switch mode {
            case .native:
                if let valueView = ObjectLogPresentationLibrary.shared.view(for: type(of: event.value)) {
                    forceTry {
                        try valueView(event.value)
                            .font(.caption)
                    }
                }
            case .description:
                Text(verbatim: String(describing: event.value)).font(.body.monospaced())
            case .debugDescription:
                Text(verbatim: String(describing: event.value)).font(.body.monospaced())
            }
        }
        .onAppear {
            nativeEnabled = ObjectLogPresentationLibrary.shared.view(for: type(of: event.value)) != nil
            if mode == .native && !nativeEnabled {
                mode = .description
            }
        }
    }
}

class ObjectLogPresentationLibrary {
    static let shared = ObjectLogPresentationLibrary()

    var views: [AnyHashable: (Any) throws -> AnyView] = [:]

    init() {
        forceTry {
            try register(type: simd_float4x4.self) { value in
                MatrixViewerView(value: value)
            }
        }
    }

    func view(for type: Any.Type) -> ((Any) throws -> AnyView)? {
        views[ObjectIdentifier(type)]
    }

    func register<T>(type: T.Type, with view: @escaping (T) -> some View) throws {
        views[ObjectIdentifier(type)] = { value in
            let value = try cast(value, as: T.self)
            return view(value).eraseToAnyView()
        }
    }
}

// NOTE: Move to Everything - use Interpolation as well
extension String {
    init<F>(_ input: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {
        self = format.format(input)
    }
}
