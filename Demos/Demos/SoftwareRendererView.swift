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

    init() {
        camera = Camera(transform: .translation([0, 0, -2]), target: [0, 0, 0], projection: .perspective(.init(fovy: .degrees(90), zClip: 0.01 ... 1000.0)))
        model = Box(min: [-0.5, -0.5, -0.5], max: [0.5, 0.5, 0.5])
        modelTransform = .init(rotation: .init(angle: .degrees(45), axis: [0, 1, 0]))
    }

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.stroke(Path { path in
                path.addLines([[-size.width / 2, 0], [size.width / 2, 0]])
            }, with: .color(Color.red), lineWidth: 0.25)
            context.stroke(Path { path in
                path.addLines([[0, -size.height / 2], [0, size.height / 2]])
            }, with: .color(Color.green), lineWidth: 0.25)

            let viewTransform = camera.transform.matrix.inverse
            let modelViewTransform = viewTransform * modelTransform.matrix
            let projectionTransform = camera.projection.matrix(viewSize: .init(size))
            let clipTransform = simd_float4x4(scale: [Float(size.width) / 2, Float(size.height) / 2, 1])

            for (index, polygon) in model.toPolygons().enumerated() {
                context.draw(polygon: polygon, projectionTransform: projectionTransform, modelViewTransform: modelViewTransform, clipTransform: clipTransform, with: .color(Color(rgb: kellyColors[index])))
            }
        }
        .overlay(alignment: .topLeading) {
            Form {
                GroupBox("Camera") {
                    CameraInspector(camera: $camera)
                }
                GroupBox("Model") {
                    TransformEditor(transform: $modelTransform)
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

extension GraphicsContext {
    func draw <V>(polygon: Polygon3D<V>, projectionTransform: simd_float4x4, modelViewTransform: simd_float4x4, clipTransform: simd_float4x4, with shading: Shading) where V: VertexLike {
//        let a = polygon.vertices[0].position
//        let b = polygon.vertices[1].position
//        let c = polygon.vertices[2].position
//        let dir = simd_normalize(simd_cross(b - a, c - a))
//        guard dir.z > 0 else {
//            return
//        }

        let modelViewProjectionTransform = projectionTransform * modelViewTransform

        let lines = polygon.vertices.map {
            let clipSpace = (clipTransform * modelViewProjectionTransform * SIMD4<Float>($0.position, 1.0))
            let screenSpace = clipSpace.xyz / clipSpace.w
            print(clipSpace, screenSpace)
            return CGPoint(screenSpace.xy)
        }
        let path = Path { path in
            path.addLines(lines)
            path.closeSubpath()
        }
        stroke(path, with: shading, lineWidth: 2)
    }
}

#Preview {
    SoftwareRendererView()
}
