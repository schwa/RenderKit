import simd
import SwiftUI
@_implementationOnly import SIMDSupport

public struct Canvas3D <Symbols>: View where Symbols: View {
    var opaque: Bool
    var colorMode: ColorRenderingMode
    var rendersAsynchronously: Bool
    var renderer: (inout GraphicsContext3D, CGSize) -> Void
    var symbols: Symbols

    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext3D, CGSize) -> Void, @ViewBuilder symbols: () -> Symbols) {
        self.opaque = opaque
        self.colorMode = colorMode
        self.rendersAsynchronously = rendersAsynchronously
        self.renderer = renderer
        self.symbols = symbols()
    }

    public var body: some View {
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

public extension Canvas3D where Symbols == EmptyView {
    init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext3D, CGSize) -> Void) {
        self.init(opaque: opaque, colorMode: colorMode, rendersAsynchronously: rendersAsynchronously, renderer: renderer, symbols: {
            EmptyView()
        })
    }
}

public struct GraphicsContext3D {
    public var graphicsContext2D: GraphicsContext
    public var projectionTransform = float4x4(diagonal: [1, 1, 1, 1])
    public var viewTransform = float4x4(diagonal: [1, 1, 1, 1])
    public var clipTransform = float4x4(diagonal: [1, 1, 1, 1])

    public var rasterizer: Rasterizer {
        return Rasterizer(graphicsContext: self)
    }

    public func project(_ point: SIMD3<Float>, viewProjectionTransform: simd_float4x4? = nil) -> CGPoint {
        let viewProjectionTransform = viewProjectionTransform ?? (projectionTransform * viewTransform)
        var point = clipTransform * viewProjectionTransform * SIMD4<Float>(point, 1.0)
        point /= point.w
        return CGPoint(point.xy)
    }

    public func stroke(path: Path3D, with shading: GraphicsContext.Shading) {
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

public struct Path3D {
    public enum Element {
        case move(to: SIMD3<Float>)
        case line(to: SIMD3<Float>)
        case closePath
    }

    public var elements: [Element] = []

    public init() {
    }

    public init(builder: (inout Path3D) -> Void) {
        var path = Path3D()
        builder(&path)
        self = path
    }

    public mutating func move(to: SIMD3<Float>) {
        elements.append(.move(to: to))
    }

    public mutating func line(to: SIMD3<Float>) {
        elements.append(.line(to: to))
    }

    public mutating func closePath() {
        elements.append(.closePath)
    }
}

public struct Rasterizer {
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

    public var graphicsContext: GraphicsContext3D
    var polygons: [ClipSpacePolygon] = []

    public mutating func submit(polygon: [SIMD3<Float>], modelViewTransform: simd_float4x4, with shading: GraphicsContext.Shading) {
        let modelViewProjectionTransform = graphicsContext.projectionTransform * modelViewTransform
        let vertices = polygon.map {
            (graphicsContext.clipTransform * modelViewProjectionTransform * SIMD4<Float>($0, 1.0))
        }
        polygons.append(ClipSpacePolygon(vertices: vertices, shading: shading))
    }

    public mutating func rasterize() {
        let polygons = polygons.filter {
            // TODO: Do actual frustrum culling.
            $0.z <= 0
        }
            .sorted { lhs, rhs in
                lhs.z < rhs.z
            }

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
