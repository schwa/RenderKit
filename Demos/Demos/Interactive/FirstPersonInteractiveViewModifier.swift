import SwiftUI
import SIMDSupport
import GameController
import simd

public struct FirstPersonInteractiveViewModifier: ViewModifier, @unchecked Sendable {
    @Environment(\.displayLink)
    var displayLink

    @State
    var movementController: MovementController?

    @FocusState
    var renderViewFocused: Bool

    @State
    var movementConsumerTask: Task<(), Never>?

    @Binding
    var camera: Camera

    public func body(content: Content) -> some View {
        content
        .task() {
            guard let displayLink else {
                return
            }
            let movementController = MovementController(displayLink: displayLink)
            movementController.focused = renderViewFocused
            self.movementController = movementController
#if os(macOS)
            movementController.disableUIKeys()
            #endif
            movementConsumerTask = Task.detached { [movementController] in
                for await event in movementController.events() {
                    Counters.shared.increment(counter: "Consumption")
                    switch event.payload {
                    case .movement(let movement):
                        let target = camera.target
                        let angle = atan2(target.z, target.x) - .pi / 2
                        let rotation = simd_quaternion(angle, [0, -1, 0])
                        Task {
                            await MainActor.run {
                                camera.transform.translation += simd_act(rotation, movement * 0.1)
                            }
                        }
                    case .rotation(let rotation):
                        Task {
                            await MainActor.run {
                                camera.heading.degrees += Float(rotation * 2)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: renderViewFocused) {
            movementController?.focused = renderViewFocused
        }
        .onDisappear {
            movementConsumerTask?.cancel()
            movementConsumerTask = nil
        }
        .focusable(interactions: .automatic)
        .focused($renderViewFocused)
        .focusEffectDisabled()
        .defaultFocus($renderViewFocused, true)
        .onKeyPress(.escape, action: {
            renderViewFocused = false
            return .handled
        })
        .overlay(alignment: .topTrailing) {
            Group {
                Group {
                    if renderViewFocused {
                        //Image(systemName: "dot.square.fill").foregroundStyle(.selection)
                        Text("Focused")
                    }
                    else {
                        Text("Unfocused")
                        //Image(systemName: "dot.square").foregroundStyle(.selection)
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
            .padding()
        }
        .overlay(alignment: .bottomLeading) {
            GameControllerWidget()
                .padding()
        }
        .overlay(alignment: .bottomLeading) {
            GameControllerWidget()
                .padding()
        }
    }
}

public extension View {
    func firstPersonInteractive(camera: Binding<Camera>) -> some View {
        modifier(FirstPersonInteractiveViewModifier(camera: camera))
    }
}
