import SwiftUI
import RenderKit
import RenderKitShaders
import RenderKitScratch
import SIMDSupport

struct SoftwareRendererView: View {
    @State
    var camera: Camera

    @State
    var model: Box

    @State
    var modelTransform: Transform

    @State
    var ballConstraint: BallConstraint

    init() {
        camera = Camera(transform: .translation([0, 0, -2]), target: [0, 0, 0], projection: .perspective(.init(fovy: .degrees(90), zClip: 0.01 ... 1000.0)))
        model = Box(min: [-0.5, -0.5, -0.5], max: [0.5, 0.5, 0.5])
        modelTransform = .init(rotation: .init(angle: .degrees(45), axis: [0, 1, 0]))
        ballConstraint = BallConstraint()
    }

    var body: some View {
        Canvas3D { context, size in
            context.graphicsContext2D.translateBy(x: size.width / 2, y: size.height / 2)
            context.graphicsContext2D.stroke(Path { path in
                path.addLines([[-size.width / 2, 0], [size.width / 2, 0]])
            }, with: .color(Color.black), lineWidth: 0.25)
            context.graphicsContext2D.stroke(Path { path in
                path.addLines([[0, -size.height / 2], [0, size.height / 2]])
            }, with: .color(Color.black), lineWidth: 0.25)

            let viewTransform = camera.transform.matrix.inverse
            let modelViewTransform = viewTransform * modelTransform.matrix
            let projectionTransform = camera.projection.matrix(viewSize: .init(size))
            let clipTransform = simd_float4x4(scale: [Float(size.width) / 2, Float(size.height) / 2, 1])

            var rasterizer = Rasterizer()

            for (index, polygon) in model.toPolygons().enumerated() {
                rasterizer.submit(polygon: polygon, projectionTransform: projectionTransform, modelViewTransform: modelViewTransform, clipTransform: clipTransform, with: .color(Color(rgb: kellyColors[index])))
            }
            rasterizer.rasterize(graphicsContext: context)
        }
        .ballRotation($ballConstraint.rotation, pitchLimit: .degrees(0) ... .degrees(0), yawLimit: .degrees(-.infinity) ... .degrees(.infinity))
        .onChange(of: ballConstraint.transform) {
            camera.transform.matrix = ballConstraint.transform
        }
        .overlay(alignment: .topLeading) {
            Form {
                GroupBox("Camera") {
                    CameraInspector(camera: $camera)
                }
                GroupBox("Model") {
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

struct Canvas3D: View {
    let renderer: (inout GraphicsContext3D, CGSize) -> Void

    var body: some View {
        Canvas { context, size in
            var graphicsContext3D = GraphicsContext3D(graphicsContext2D: context)
            renderer(&graphicsContext3D, size)
        }
    }
}

struct GraphicsContext3D {
    var graphicsContext2D: GraphicsContext
}

struct Rasterizer {
    struct ClipSpacePolygon {
        var vertices: [SIMD4<Float>]
        var shading: GraphicsContext.Shading
        var z: Float

        init(vertices: [SIMD4<Float>], shading: GraphicsContext.Shading) {
            self.vertices = vertices
            self.shading = shading
            self.z = vertices.map(\.z).reduce(0, +) / Float(vertices.count)
        }
    }

    var polygons: [ClipSpacePolygon] = []

    mutating func submit<V>(polygon: Polygon3D<V>, projectionTransform: simd_float4x4, modelViewTransform: simd_float4x4, clipTransform: simd_float4x4, with shading: GraphicsContext.Shading) where V: VertexLike {
        let modelViewProjectionTransform = projectionTransform * modelViewTransform
        let vertices = polygon.vertices.map {
            (clipTransform * modelViewProjectionTransform * SIMD4<Float>($0.position, 1.0))
        }
        polygons.append(ClipSpacePolygon(vertices: vertices, shading: shading))
    }

    mutating func rasterize(graphicsContext: GraphicsContext3D) {
        let polygons = polygons.filter {
            // TODO: Do actual frustrum culling.
            $0.z <= 0
        }
        .sorted(by: \.z)

        //        let a = polygon.vertices[0].position
        //        let b = polygon.vertices[1].position
        //        let c = polygon.vertices[2].position
        //        let dir = simd_normalize(simd_cross(b - a, c - a))
        //        guard dir.z > 0 else {
        //            return
        //        }

        for polygon in polygons {
            let lines = polygon.vertices.map {
                let screenSpace = $0.xyz / $0.w
                return CGPoint(screenSpace.xy)
            }
            let path = Path { path in
                path.addLines(lines)
                path.closeSubpath()
            }
            graphicsContext.graphicsContext2D.stroke(path, with: polygon.shading, lineWidth: 2)
        }
    }
}

#Preview {
    SoftwareRendererView()
}

struct BallConstraint {
    var radius: Float = 0
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
