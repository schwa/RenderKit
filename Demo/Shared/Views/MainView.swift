import Everything
import Foundation
import RenderKit
import simd
import SwiftUI
import RenderKitSupport
import RenderKitDemo

struct MainView: View, Sendable {
    @EnvironmentObject
    var renderModel: DemoModel

    @Environment(\.displayLink)
    var displayLink

    @State
    @MainActor
    var mouselook = true

    var body: some View {
        RenderView(device: renderModel.device, renderer: renderModel.renderer)
            .overlay(alignment: .bottomLeading) {
                Button(mouselook ? "Disable Mouselook (⌘⎋)" : "Enable Mouselook (⌘⎋)") {
                    mouselook.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(mouselook ? Color.mint : Color.yellow)
                .keyboardShortcut(.init(.escape, modifiers: .command))
                .padding()
            }
        #if os(macOS)
            .task {
                for await delta in CapturedMouseStream() {
                    guard mouselook else {
                        continue
                    }
                    guard delta.x != 0 else {
                        continue
                    }
                    renderModel.sceneGraph.cameraController.heading.degrees += Float(delta.x)
                }
            }
            .task {
                for await movement in WASDStream(displayLinkPublisher: displayLink) {
                    let target = renderModel.sceneGraph.cameraController.target
                    let angle = atan2(target.z, target.x) - .pi / 2
                    let rotation = simd_quaternion(angle, [0, -1, 0])
                    let movement = SIMD3<Float>(Float(movement.x), 0, Float(movement.y)) * [-1, 1, -1] * 0.1
                    renderModel.sceneGraph.cameraController.position += simd_act(rotation, movement)
                }
            }
        #endif
    }
}
