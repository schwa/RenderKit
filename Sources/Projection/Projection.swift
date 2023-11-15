import simd
import SwiftUI

public struct Projection3D {
    public var size: CGSize
    public var projectionTransform = simd_float4x4(diagonal: .init(repeating: 1))
    public var viewTransform = simd_float4x4(diagonal: .init(repeating: 1))
    public var clipTransform = simd_float4x4(diagonal: .init(repeating: 1))

    public init(size: CGSize, projectionTransform: simd_float4x4 = simd_float4x4(diagonal: [1, 1, 1, 1]), viewTransform: simd_float4x4 = simd_float4x4(diagonal: [1, 1, 1, 1]), clipTransform: simd_float4x4 = simd_float4x4(diagonal: [1, 1, 1, 1])) {
        self.size = size
        self.projectionTransform = projectionTransform
        self.viewTransform = viewTransform
        self.clipTransform = clipTransform
    }

    public func project(_ point: SIMD3<Float>) -> CGPoint {
        var point = clipTransform * projectionTransform * viewTransform * SIMD4<Float>(point, 1.0)
        point /= point.w
        return CGPoint(x: Double(point.x), y: Double(point.y))
    }
}

// MARK: -

public extension GraphicsContext {
    func draw3DLayer(projection: Projection3D, content: (inout GraphicsContext, inout GraphicsContext3D) -> Void) {
        drawLayer { context in
            context.translateBy(x: projection.size.width / 2, y: projection.size.height / 2)
            var graphicsContext = GraphicsContext3D(graphicsContext2D: context, projection: projection)
            content(&context, &graphicsContext)
        }
    }
}

public struct GraphicsContext3D {
    public var graphicsContext2D: GraphicsContext
    public var projection: Projection3D

    public var rasterizer: Rasterizer {
        return Rasterizer(graphicsContext: self)
    }

    public init(graphicsContext2D: GraphicsContext, projection: Projection3D) {
        self.graphicsContext2D = graphicsContext2D
        self.projection = projection
    }

    public func stroke(path: Path3D, with shading: GraphicsContext.Shading) {
        let viewProjectionTransform = projection.projectionTransform * projection.viewTransform
        let path = Path { path2D in
            for element in path.elements {
                switch element {
                case .move(let point):
                    let transform = projection.clipTransform * viewProjectionTransform
                    var point = transform * SIMD4<Float>(point, 1.0)
                    point /= point.w
                    path2D.move(to: CGPoint(x: Double(point.x), y: Double(point.y)))
                case .addLine(let point):
                    let transform = projection.clipTransform * viewProjectionTransform
                    var point = transform * SIMD4<Float>(point, 1.0)
                    point /= point.w
                    path2D.addLine(to: CGPoint(x: Double(point.x), y: Double(point.y)))
                case .closePath:
                    path2D.closeSubpath()
                }
            }
        }
        print(path)
        graphicsContext2D.stroke(path, with: shading)
    }
}

// MARK: -

public struct Path3D {
    public enum Element {
        case move(to: SIMD3<Float>)
        case addLine(to: SIMD3<Float>)
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

    public mutating func addLine(to: SIMD3<Float>) {
        elements.append(.addLine(to: to))
    }

    public mutating func closePath() {
        elements.append(.closePath)
    }
}

// MARK: -

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

    public mutating func submit(polygon: [SIMD3<Float>], with shading: GraphicsContext.Shading) {
        let modelViewTransform = graphicsContext.projection.viewTransform
        let modelViewProjectionTransform = graphicsContext.projection.projectionTransform * modelViewTransform
        let vertices = polygon.map {
            (graphicsContext.projection.clipTransform * modelViewProjectionTransform * SIMD4<Float>($0, 1.0))
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
                let screenSpace = SIMD3($0.x, $0.y, $0.z) / $0.w
                return CGPoint(x: Double(screenSpace.x), y: Double(screenSpace.y))
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
