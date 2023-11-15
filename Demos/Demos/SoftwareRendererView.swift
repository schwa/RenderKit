import SwiftUI
import RenderKit
import RenderKitShaders
import RenderKitScratch
import SIMDSupport
import Projection

struct SoftwareRendererView: View {
    @State
    var camera: Camera

    @State
    var models: [any PolygonConvertable]

    @State
    var modelTransform: Transform

    @State
    var ballConstraint: BallConstraint

    init() {
        camera = Camera(transform: .translation([0, 0, -5]), target: [0, 0, 0], projection: .perspective(.init(fovy: .degrees(90), zClip: 0.01 ... 1000.0)))
        models = [
            Box(min: [-1, -0.5, -0.5], max: [-2.0, 0.5, 0.5]),
            //Box(min: [-0.5, -0.5, -0.5], max: [0.5, 0.5, 0.5]),
            Sphere(center: .zero, radius: 0.5),
            Box(min: [1, -0.5, -0.5], max: [2.0, 0.5, 0.5]),
        ]
        modelTransform = .init(rotation: .init(angle: .degrees(0), axis: [0, 1, 0]))
        ballConstraint = BallConstraint()
    }

    var body: some View {
        Canvas { context, size in
            var projection = Projection3D(size: size)
            projection.viewTransform = camera.transform.matrix.inverse
            projection.projectionTransform = camera.projection.matrix(viewSize: .init(size))
            projection.clipTransform = simd_float4x4(scale: [Float(size.width) / 2, Float(size.height) / 2, 1])

            context.draw3DLayer(projection: projection) { context, context3D in
                context3D.stroke(path: Path3D { path in
                    path.move(to: [-5, 0, 0])
                    path.addLine(to: [5, 0, 0])
                }, with: .color(.red))
                context3D.stroke(path: Path3D { path in
                    path.move(to: [0, -5, 0])
                    path.addLine(to: [0, 5, 0])
                }, with: .color(.green))
                context3D.stroke(path: Path3D { path in
                    path.move(to: [0, 0, -5])
                    path.addLine(to: [0, 0, 5])
                }, with: .color(.blue))

                if let symbol = context.resolveSymbol(id: "-X") {
                    context.draw(symbol, at: projection.project([-5, 0, 0]))
                }
                if let symbol = context.resolveSymbol(id: "+X") {
                    context.draw(symbol, at: projection.project([5, 0, 0]))
                }
                if let symbol = context.resolveSymbol(id: "-Y") {
                    context.draw(symbol, at: projection.project([0, -5, 0]))
                }
                if let symbol = context.resolveSymbol(id: "+Y") {
                    context.draw(symbol, at: projection.project([0, 5, 0]))
                }
                if let symbol = context.resolveSymbol(id: "-Z") {
                    context.draw(symbol, at: projection.project([0, 0, -5]))
                }
                if let symbol = context.resolveSymbol(id: "+Z") {
                    context.draw(symbol, at: projection.project([0, 0, 5]))
                }

                var rasterizer = context3D.rasterizer
                for model in models {
                    for (index, polygon) in model.toPolygons().enumerated() {
                        rasterizer.submit(polygon: polygon.vertices.map { $0.position }, with: .color(Color(rgb: kellyColors[index % kellyColors.count]).opacity(0.8)))
                    }
                }
                rasterizer.rasterize()
            }
        }
        symbols: {
            ForEach(["-X", "+X", "-Y", "+Y", "-Z", "+Z"], id: \.self) { value in
                Text(value).tag(value).font(.caption).background(.white.opacity(0.5))
            }
        }
        .ballRotation($ballConstraint.rotation, pitchLimit: .degrees(-.infinity) ... .degrees(.infinity), yawLimit: .degrees(-.infinity) ... .degrees(.infinity))
        .onAppear() {
            camera.transform.matrix = ballConstraint.transform
            print(camera.transform.matrix)
        }
        .onChange(of: ballConstraint.transform) {
            camera.transform.matrix = ballConstraint.transform
        }
        .overlay(alignment: .topLeading) {
            Form {
                GroupBox("Camera") {
                    CameraInspector(camera: $camera)
                }
                GroupBox("Model Transform") {
                    TransformEditor(transform: $modelTransform)
                }
                GroupBox("Ball Constraint") {
                    BallConstraintEditor(ballConstraint: $ballConstraint)
                }
            }
            .padding(4)
            .background(.regularMaterial)
            .controlSize(.mini)
            .frame(width: 200)
            .padding(4)
        }
    }
}

#Preview {
    SoftwareRendererView()
}

struct BallConstraint {
    var radius: Float = -5
    var lookAt: SIMD3<Float> = .zero
    var rotation: Rotation = .zero

    var transform: simd_float4x4 {
        return rotation.matrix * simd_float4x4(translate: [0, 0, radius])
    }
}

struct BallConstraintEditor: View {
    @Binding
    var ballConstraint: BallConstraint

    var body: some View {
        TextField("Radius", value: $ballConstraint.radius, format: .number)
        TextField("Look AT", value: $ballConstraint.lookAt, format: .vector)
        TextField("Pitch", value: $ballConstraint.rotation.pitch, format: .angle)
        TextField("Yaw", value: $ballConstraint.rotation.yaw, format: .angle)
    }
}

//            for angle in stride(from: Float.zero, to: 360.0, by: 45.0) {
//                let angle = Angle<Float>(degrees: angle)
//                context.stroke(path: Path3D { path in
//                    path.move(to: [0, 0, 0])
//                    path.line(to: [0, cos(angle.radians) * 5, sin(angle.radians) * 5])
//                }, with: .color(.red))
//                context.stroke(path: Path3D { path in
//                    path.move(to: [0, 0, 0])
//                    path.line(to: [cos(angle.radians) * 5, 0, sin(angle.radians) * 5])
//                }, with: .color(.green))
//                context.stroke(path: Path3D { path in
//                    path.move(to: [0, 0, 0])
//                    path.line(to: [cos(angle.radians) * 5, sin(angle.radians) * 5, 0])
//                }, with: .color(.blue))
//            }
