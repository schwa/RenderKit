import SwiftUI
import RenderKit
import RenderKitShaders
import RenderKitScratch
import SIMDSupport

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
        Canvas3D { context, size in
            context.viewTransform = camera.transform.matrix.inverse
            context.projectionTransform = camera.projection.matrix(viewSize: .init(size))
            context.clipTransform = simd_float4x4(scale: [Float(size.width) / 2, Float(size.height) / 2, 1])
            let modelViewTransform = context.viewTransform * modelTransform.matrix

            context.stroke(path: Path3D { path in
                path.move(to: [-5, 0, 0])
                path.line(to: [5, 0, 0])
            }, with: .color(.red))
            context.stroke(path: Path3D { path in
                path.move(to: [0, -5, 0])
                path.line(to: [0, 5, 0])
            }, with: .color(.green))
            context.stroke(path: Path3D { path in
                path.move(to: [0, 0, -5])
                path.line(to: [0, 0, 5])
            }, with: .color(.blue))

            if let symbol = context.graphicsContext2D.resolveSymbol(id: "-X") {
                context.graphicsContext2D.draw(symbol, at: context.project([-5, 0, 0]))
            }
            if let symbol = context.graphicsContext2D.resolveSymbol(id: "+X") {
                context.graphicsContext2D.draw(symbol, at: context.project([5, 0, 0]))
            }
            if let symbol = context.graphicsContext2D.resolveSymbol(id: "-Y") {
                context.graphicsContext2D.draw(symbol, at: context.project([0, -5, 0]))
            }
            if let symbol = context.graphicsContext2D.resolveSymbol(id: "+Y") {
                context.graphicsContext2D.draw(symbol, at: context.project([0, 5, 0]))
            }
            if let symbol = context.graphicsContext2D.resolveSymbol(id: "-Z") {
                context.graphicsContext2D.draw(symbol, at: context.project([0, 0, -5]))
            }
            if let symbol = context.graphicsContext2D.resolveSymbol(id: "+Z") {
                context.graphicsContext2D.draw(symbol, at: context.project([0, 0, 5]))
            }

            var rasterizer = context.rasterizer
            for model in models {
                for (index, polygon) in model.toPolygons().enumerated() {
                    rasterizer.submit(polygon: polygon, modelViewTransform: modelViewTransform, with: .color(Color(rgb: kellyColors[index % kellyColors.count]).opacity(0.8)))
                }
            }
            rasterizer.rasterize()
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

struct Canvas3D <Symbols>: View where Symbols: View {
    var opaque: Bool
    var colorMode: ColorRenderingMode
    var rendersAsynchronously: Bool
    var renderer: (inout GraphicsContext3D, CGSize) -> Void
    var symbols: Symbols

    init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext3D, CGSize) -> Void, @ViewBuilder symbols: () -> Symbols) {
        self.opaque = opaque
        self.colorMode = colorMode
        self.rendersAsynchronously = rendersAsynchronously
        self.renderer = renderer
        self.symbols = symbols()
    }

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width / 2, y: size.height / 2)
            var graphicsContext3D = GraphicsContext3D(graphicsContext2D: context)
            renderer(&graphicsContext3D, size)
        }
        symbols: {
            symbols
        }
    }
}

extension Canvas3D where Symbols == EmptyView {
    init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext3D, CGSize) -> Void) {
        self.init(opaque: opaque, colorMode: colorMode, rendersAsynchronously: rendersAsynchronously, renderer: renderer, symbols: {
            EmptyView()
        })
    }
}

struct GraphicsContext3D {
    var graphicsContext2D: GraphicsContext

    var projectionTransform = float4x4.identity
    var viewTransform = float4x4.identity
    var clipTransform = float4x4.identity

    var rasterizer: Rasterizer {
        return Rasterizer(graphicsContext: self)
    }

    func project(_ point: SIMD3<Float>, viewProjectionTransform: simd_float4x4? = nil) -> CGPoint {
        let viewProjectionTransform = viewProjectionTransform ?? (projectionTransform * viewTransform)
        var point = clipTransform * viewProjectionTransform * SIMD4<Float>(point, 1.0)
        point /= point.w
        return CGPoint(point.xy)
    }

    func stroke(path: Path3D, with shading: GraphicsContext.Shading) {
        let viewProjectionTransform = projectionTransform * viewTransform
        let path = Path { path2D in
            for element in path.elements {
                switch element {
                case .move(let point):
                    var point = clipTransform * viewProjectionTransform * SIMD4<Float>(point, 1.0)
                    point /= point.w
                    path2D.move(to: CGPoint(point.xy))
                case .line(let point):
                    var point = clipTransform * viewProjectionTransform * SIMD4<Float>(point, 1.0)
                    point /= point.w
                    path2D.addLine(to: CGPoint(point.xy))
                case .closePath:
                    path2D.closeSubpath()
                }
            }
        }
        print(path)
        graphicsContext2D.stroke(path, with: shading)
    }
}

struct Path3D {
    enum Element {
        case move(to: SIMD3<Float>)
        case line(to: SIMD3<Float>)
        case closePath
    }

    var elements: [Element] = []

    init() {
    }

    init(builder: (inout Path3D) -> Void) {
        var path = Path3D()
        builder(&path)
        self = path
    }

    mutating func move(to: SIMD3<Float>) {
        elements.append(.move(to: to))
    }

    mutating func line(to: SIMD3<Float>) {
        elements.append(.line(to: to))
    }

    mutating func closePath() {
        elements.append(.closePath)
    }
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

    var graphicsContext: GraphicsContext3D
    var polygons: [ClipSpacePolygon] = []

    mutating func submit<V>(polygon: Polygon3D<V>, modelViewTransform: simd_float4x4, with shading: GraphicsContext.Shading) where V: VertexLike {
        let modelViewProjectionTransform = graphicsContext.projectionTransform * modelViewTransform
        let vertices = polygon.vertices.map {
            (graphicsContext.clipTransform * modelViewProjectionTransform * SIMD4<Float>($0.position, 1.0))
        }
        polygons.append(ClipSpacePolygon(vertices: vertices, shading: shading))
    }

    mutating func rasterize() {
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
            graphicsContext.graphicsContext2D.fill(path, with: polygon.shading)
            //graphicsContext.graphicsContext2D.stroke(path, with: .color(.black), style: .init(lineWidth: 1, lineCap: .round, lineJoin: .round))
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
