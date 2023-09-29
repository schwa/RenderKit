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
    var scene: SimpleScene

    public func body(content: Content) -> some View {
        content
        .onAppear {
            guard let displayLink else {
                return
            }
            movementController = MovementController(displayLink: displayLink)
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
                if renderViewFocused {
                    Image(systemName: "dot.square.fill").foregroundStyle(.selection)
                }
                else {
                    Image(systemName: "dot.square").foregroundStyle(.selection)
                }
            }
            .padding()
        }
        .overlay(alignment: .bottomLeading) {
            GameControllerWidget()
                .padding()
        }
        .task() {
            movementConsumerTask = Task.detached { [movementController] in
                guard let movementController else {
                    return
                }
                for await event in movementController.events() {
                    Counters.shared.increment(counter: "Consumption")
                    switch event.payload {
                    case .movement(let movement):
                        let target = scene.camera.target
                        let angle = atan2(target.z, target.x) - .pi / 2
                        let rotation = simd_quaternion(angle, [0, -1, 0])
                        Task {
                            await MainActor.run {
                                scene.camera.transform.translation += simd_act(rotation, movement * 0.1)
                            }
                        }
                    case .rotation(let rotation):
                        Task {
                            await MainActor.run {
                                scene.camera.heading.degrees += Float(rotation * 2)
                            }
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .onAppear {
            movementController?.disableUIKeys()
        }
        #endif
        .onChange(of: renderViewFocused) {
            movementController?.focused = renderViewFocused
        }
        .overlay(alignment: .bottomLeading) {
            GameControllerWidget()
                .padding()
        }
    }
}

public extension View {
    func firstPersonInteractive(scene: Binding<SimpleScene>) -> some View {
        modifier(FirstPersonInteractiveViewModifier(scene: scene))
    }
}
