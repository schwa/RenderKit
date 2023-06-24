import Everything
import RenderKit
import SIMDSupport
import SwiftUI
import RenderKitSceneGraph

struct MapView: View {
    @EnvironmentObject
    var model: SceneGraph

    enum Mode {
        case small
        case large

        mutating func toggle() {
            switch self {
            case .small:
                self = .large
            case .large:
                self = .small
            }
        }
    }

    @State
    var mode = Mode.small

    let scale: Double = 10

    func point(for transform: Transform, size: CGSize) -> CGPoint {
        CGPoint(transform.translation.xz) * scale + (size / 2)
    }

    func convert(vector: SIMD3<Float>, size: CGSize) -> CGPoint {
        CGPoint(vector.xz) * scale + (size / 2)
    }

    func convert(point: CGPoint, size: CGSize) -> SIMD3<Float> {
        let point = (point - size / 2) / scale
        return SIMD3<Float>(x: Float(point.x), y: 0, z: Float(point.y))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(model.lightingModel.lights) { light in
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.yellow)
                        .position(point(for: light.transform, size: proxy.size))
                        .gesture(DragGesture().onChanged({ value in
                            light.transform.translation.xz = convert(point: value.location, size: proxy.size).xz
                        }))
                }
                ForEach(model.entities) { entity in
                    Image(systemName: "cube.fill")
                        .foregroundColor(.purple)
                        .position(point(for: entity.transform, size: proxy.size))
                        .gesture(DragGesture().onChanged({ value in
                            let index = model.entities.firstIndex(where: { $0.id == entity.id })!
                            model.entities[index].transform.translation.xz = convert(point: value.location, size: proxy.size).xz
                        }))
                }
                Image(systemName: "camera.circle")
                    .foregroundColor(.cyan)
                    .position(convert(vector: model.cameraController.position, size: proxy.size))
                    .gesture(DragGesture().onChanged({ value in
                        model.cameraController.position.xz = convert(point: value.location, size: proxy.size).xz
                    }))
                Image(systemName: "scope")
                    .foregroundColor(.cyan)
                    .position(convert(vector: model.cameraController.position + model.cameraController.target, size: proxy.size))
                    .gesture(DragGesture().onChanged({ value in
                        model.cameraController.target.xz = (convert(point: value.location, size: proxy.size).xz - model.cameraController.position.xz) // .normalized
                    }))
            }
        }
        .clipped()
        .imageScale(.large)
        .background(Color.white.cornerRadius(8).opacity(0.8))
        .overlay(alignment: .bottomTrailing) {
            Button(systemImage: "arrow.up.left.and.arrow.down.right") {
                withAnimation { mode.toggle() }
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(4)
        }
        .frame(width: mode == .small ? 160 : nil, height: mode == .small ? 160 : nil)
        .padding()
        .onReceive(model.scene.publisher.receive(on: DispatchQueue.main)) { _ in
            model.objectWillChange.send()
        }
    }
}
