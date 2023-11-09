// from https://github.com/evanw/csg.js/blob/master/csg.js#L291

import RenderKit
import RenderKitShaders
import simd
import SIMDSupport

public struct CSG<Vertex> where Vertex: VertexLike {
    public typealias Polygon = Polygon3D<Vertex>

    public var polygons: [Polygon]

    class Node {
        var plane: Plane?
        var front: Node?
        var back: Node?
        var polygons: [Polygon]

        init(plane: Plane? = nil, front: Node? = nil, back: Node? = nil, polygons: [Polygon] = []) {
            self.plane = plane
            self.front = front
            self.back = back
            self.polygons = polygons
        }
    }
}

public extension CSG {
    internal init(node: Node) {
        self.polygons = node.allPolygons
    }

    func union(_ other: Self) -> Self {
        let a = Node(polygons: polygons)
        let b = Node(polygons: other.polygons)
        a.clip(to: b)
        b.clip(to: a)
        b.invert()
        b.clip(to: a)
        return Self(polygons: a.allPolygons + b.allPolygons)
    }

    func subtracting(_ other: Self) -> Self {
        let a = Node(polygons: polygons)
        let b = Node(polygons: other.polygons)
        a.invert()
        a.clip(to: b)
        b.clip(to: a)
        b.invert()
        b.clip(to: a)
        var polygons = a.allPolygons + b.allPolygons
        a.invert()
        polygons = a.allPolygons + b.allPolygons
        return Self(polygons: polygons)
    }

    func intersecting(_ other: Self) -> Self {
        let a = Node(polygons: polygons)
        let b = Node(polygons: other.polygons)
        a.invert()
        b.clip(to: a)
        b.invert()
        a.clip(to: b)
        b.clip(to: a)
        var polygons = a.allPolygons + b.allPolygons
        a.invert()
        polygons = a.allPolygons + b.allPolygons
        return Self(polygons: polygons)
    }

    func inverted() -> Self {
        return Self(polygons: polygons.map { $0.flipped() })
    }

    func split(plane: Plane) -> (Self, Self) {
        var coplanarFront: [Polygon] = []
        var coplanarBack: [Polygon] = []
        var front: [Polygon] = []
        var back: [Polygon] = []

        for polygon in polygons {
            let result = polygon.split(plane: plane)
            coplanarFront += result.coplanarFront
            coplanarBack += result.coplanarBack
            front += result.front
            back += result.back
        }

        return (CSG(polygons: coplanarFront + front), CSG(polygons: coplanarBack + back))
    }
}

extension CSG.Node {
    typealias Polygon = CSG.Polygon

    convenience init(polygons: [Polygon]) {
        self.init()
        insert(polygons: polygons)
    }

    // Build a BSP tree out of `polygons`. When called on an existing tree, the
    // new polygons are filtered down to the bottom of the tree and become new
    // nodes there. Each set of polygons is partitioned using the first polygon
    // (no heuristic is used to pick a good split).
    func insert(polygons: [Polygon]) {
        if polygons.isEmpty {
            return
        }

        if plane == nil {
            plane = polygons[0].plane
        }

        var front: [Polygon] = []
        var back: [Polygon] = []

        for polygon in polygons {
            let result = polygon.split(plane: plane!)
            front += result.front
            back += result.back
            self.polygons += result.coplanarFront + result.coplanarBack
        }

        if !front.isEmpty {
            if self.front == nil {
                self.front = CSG.Node(polygons: front)
            }
            else {
                self.front!.insert(polygons: front)
            }
        }

        if !back.isEmpty {
            if self.back == nil {
                self.back = CSG.Node(polygons: back)
            }
            else {
                self.back!.insert(polygons: back)
            }
        }
    }

    // Convert solid space to empty space and empty space to solid space.
    func invert() {
        polygons = polygons.map { $0.flipped() }
        plane!.flip()
        if let front {
            front.invert()
        }
        if let back {
            back.invert()
        }
        swap(&front, &back)
    }

    // Recursively remove all polygons in `polygons` that are inside this BSP tree.
    func clip(polygons: [Polygon]) -> [Polygon] {
        if plane == nil {
            return []
        }

        var coplanarFront: [Polygon] = []
        var coplanarBack: [Polygon] = []
        var front: [Polygon] = []
        var back: [Polygon] = []

        for polygon in polygons {
            let result = polygon.split(plane: plane!)
            coplanarFront += result.coplanarFront
            coplanarBack += result.coplanarBack
            front += result.front
            back += result.back
        }

        front = coplanarFront + front
        back = coplanarBack + back

        if self.front != nil {
            front = self.front!.clip(polygons: front)
        }
        if self.back != nil {
            back = self.back!.clip(polygons: back)
        }
        return front + back
    }

    // Remove all polygons in this BSP tree that are inside the other BSP tree.
    func clip(to node: CSG.Node) {
        polygons = node.clip(polygons: polygons)
        if let front {
            front.clip(to: node)
        }
        if let back {
            back.clip(to: node)
        }
    }

    var allPolygons: [Polygon] {
        var polygons = polygons
        if let front {
            polygons += front.allPolygons
        }
        if let back {
            polygons += back.allPolygons
        }
        return polygons
    }
}

private enum SplitType: Int {
    case coplanar = 0
    case front = 1
    case back = 2
    case spanning = 3
}

extension SplitType {
    static func | (lhs: Self, rhs: Self) -> Self {
        return SplitType(rawValue: lhs.rawValue | rhs.rawValue)!
    }
}

extension Polygon3D {
    func split(plane: Plane) -> (coplanarFront: [Self], coplanarBack: [Self], front: [Self], back: [Self]) {
        var coplanarFront: [Self] = []
        var coplanarBack: [Self] = []
        var front: [Self] = []
        var back: [Self] = []

        let EPSILON: Float = 1e-5
        var polygonType = SplitType.coplanar
        var types: [SplitType] = []
        for vertex in vertices {
            let t = simd.dot(plane.normal, vertex.position) - plane.w
            let type: SplitType
            if t < -EPSILON {
                type = .back
            }
            else if t > EPSILON {
                type = .front
            }
            else {
                type = .coplanar
            }
            polygonType = SplitType(rawValue: polygonType.rawValue | type.rawValue)!
            types.append(type)
        }

        switch polygonType {
        case .coplanar:
            if simd.dot(plane.normal, vertices[0].position) - plane.w < 0 {
                coplanarBack.append(self)
            }
            else {
                coplanarFront.append(self)
            }
        case .front:
            front.append(self)
        case .back:
            back.append(self)
        case .spanning:
            var f: [Vertex] = []
            var b: [Vertex] = []
            for (i, j) in zip(vertices, types).circularPairs() {
                let (vi, ti) = i
                let (vj, tj) = j
                if ti != .back {
                    f.append(vi)
                }
                if ti != .front {
                    // b.append(ti != .back ? vi.clone() : vi)
                    b.append(vi)
                }
                if ti | tj == .spanning {
                    let t = (plane.w - plane.normal.dot(vi.position)) / plane.normal.dot(vj.position - vi.position)
                    let v = vi.interpolate(vj, t)
                    f.append(v)
                    b.append(v)
                }
            }
            if f.count >= 3 {
                front.append(Polygon3D(vertices: f))
            }
            if b.count >= 3 {
                back.append(Polygon3D(vertices: b))
            }
        }

        return (coplanarFront, coplanarBack, front, back)
    }
}

// MARK: -

extension SimpleVertex: VertexLike {
}

extension SIMD3 where Scalar == Float {
    func dot(_ other: Self) -> Float {
        simd_dot(self, other)
    }
}

extension VertexLike {
    func interpolate(_ other: Self, _ value: Float) -> Self {
        var result = Self()
        result.position = simd_mix(position, other.position, .init(repeating: value))
        result.normal = simd_mix(normal, other.normal, .init(repeating: value))
        return result
    }
}

extension SimpleVertex {
    init(position: SIMD3<Float>, normal: SIMD3<Float>) {
        self.init(position: position, normal: normal, textureCoordinate: .zero)
    }
}

public extension Box {
    func toCSG() -> CSG<SimpleVertex> {
        let polygons = [
            Polygon3D(vertices: [
                SimpleVertex(position: SIMD3<Float>(min.x, min.y, min.z), normal: .init(x: -1, y: 0, z: 0)),
                SimpleVertex(position: SIMD3<Float>(min.x, max.y, min.z), normal: .init(x: -1, y: 0, z: 0)),
                SimpleVertex(position: SIMD3<Float>(min.x, max.y, max.z), normal: .init(x: -1, y: 0, z: 0)),
                SimpleVertex(position: SIMD3<Float>(min.x, min.y, max.z), normal: .init(x: -1, y: 0, z: 0)),
            ]).flipped(),

            Polygon3D(vertices: [
                SimpleVertex(position: SIMD3<Float>(max.x, min.y, min.z), normal: .init(x: 1, y: 0, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, min.y, max.z), normal: .init(x: 1, y: 0, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, max.y, max.z), normal: .init(x: 1, y: 0, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, max.y, min.z), normal: .init(x: 1, y: 0, z: 0)),
            ]).flipped(),
            Polygon3D(vertices: [
                SimpleVertex(position: SIMD3<Float>(min.x, min.y, min.z), normal: .init(x: 0, y: -1, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, min.y, min.z), normal: .init(x: 0, y: -1, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, min.y, max.z), normal: .init(x: 0, y: -1, z: 0)),
                SimpleVertex(position: SIMD3<Float>(min.x, min.y, max.z), normal: .init(x: 0, y: -1, z: 0)),
            ]),
            Polygon3D(vertices: [
                SimpleVertex(position: SIMD3<Float>(min.x, max.y, min.z), normal: .init(x: 0, y: 1, z: 0)),
                SimpleVertex(position: SIMD3<Float>(min.x, max.y, max.z), normal: .init(x: 0, y: 1, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, max.y, max.z), normal: .init(x: 0, y: 1, z: 0)),
                SimpleVertex(position: SIMD3<Float>(max.x, max.y, min.z), normal: .init(x: 0, y: 1, z: 0)),
            ]),
            Polygon3D(vertices: [
                SimpleVertex(position: SIMD3<Float>(min.x, min.y, min.z), normal: .init(x: 0, y: 0, z: -1)),
                SimpleVertex(position: SIMD3<Float>(min.x, max.y, min.z), normal: .init(x: 0, y: 0, z: -1)),
                SimpleVertex(position: SIMD3<Float>(max.x, max.y, min.z), normal: .init(x: 0, y: 0, z: -1)),
                SimpleVertex(position: SIMD3<Float>(max.x, min.y, min.z), normal: .init(x: 0, y: 0, z: -1)),
            ]),
            Polygon3D(vertices: [
                SimpleVertex(position: SIMD3<Float>(min.x, min.y, max.z), normal: .init(x: 0, y: 0, z: 1)),
                SimpleVertex(position: SIMD3<Float>(max.x, min.y, max.z), normal: .init(x: 0, y: 0, z: 1)),
                SimpleVertex(position: SIMD3<Float>(max.x, max.y, max.z), normal: .init(x: 0, y: 0, z: 1)),
                SimpleVertex(position: SIMD3<Float>(min.x, max.y, max.z), normal: .init(x: 0, y: 0, z: 1)),
            ]),
        ]
        return CSG(polygons: polygons)
    }
}

public extension Sphere {
    func toCSG() -> CSG<SimpleVertex> {
        let slices = 36
        let stacks = 36
        var polygons: [Polygon3D<SimpleVertex>] = []
        func vertex(_ theta: Angle<Float>, _ phi: Angle<Float>) -> SimpleVertex {
            let dir = SIMD3<Float>(cos(theta.radians) * sin(phi.radians), cos(phi.radians), sin(theta.radians) * sin(phi.radians))
            return SimpleVertex(position: dir * radius + center, normal: dir)
        }
        for i in 0 ..< slices {
            for j in 0 ..< stacks {
                let v1 = vertex(.degrees(Float(i) / Float(slices) * 360), .degrees(Float(j) / Float(stacks) * 180))
                let v2 = vertex(.degrees(Float(i + 1) / Float(slices) * 360), .degrees(Float(j) / Float(stacks) * 180))
                let v3 = vertex(.degrees(Float(i + 1) / Float(slices) * 360), .degrees(Float(j + 1) / Float(stacks) * 180))
                let v4 = vertex(.degrees(Float(i) / Float(slices) * 360), .degrees(Float(j + 1) / Float(stacks) * 180))
                polygons.append(Polygon3D(vertices: [v1, v2, v3]))
                polygons.append(Polygon3D(vertices: [v1, v3, v4]))
            }
        }
        return CSG(polygons: polygons)
    }
}

extension Triangle3D {
    func toCSG() -> CSG<SimpleVertex> {
        let v1 = SimpleVertex(position: vertices.0, normal: .zero)
        let v2 = SimpleVertex(position: vertices.1, normal: .zero)
        let v3 = SimpleVertex(position: vertices.2, normal: .zero)
        return CSG(polygons: [Polygon3D(vertices: [v1, v2, v3])])
    }
}

public extension CSG {
    func toPLY() -> String {
        let vertices = polygons.flatMap { $0.vertices }
        let faces: [[Int]] = polygons.reduce(into: []) { partialResult, polygon in
            let nextIndex = partialResult.map { $0.count }.reduce(0, +)
            partialResult.append(Array(nextIndex ..< nextIndex + polygon.vertices.count))
        }
        var s = ""
        let encoder = PlyEncoder()
        encoder.encodeHeader(to: &s)
        encoder.encodeVersion(to: &s)
        encoder.encodeElementDefinition(name: "vertex", count: vertices.count, properties: [
            (.float, "x"), (.float, "y"), (.float, "z"),
            (.float, "nx"), (.float, "ny"), (.float, "nz"),
            (.uchar, "red"), (.uchar, "green"), (.uchar, "blue"),
        ], to: &s)
        encoder.encodeElementDefinition(name: "face", count: faces.count, properties: [
            (.list(count: .uchar, element: .int), "vertex_indices")
        ], to: &s)
        encoder.encodeEndHeader(to: &s)

        for vertex in vertices {
            encoder.encodeElement([
                .float(vertex.position.x), .float(vertex.position.y), .float(vertex.position.z),
                .float(vertex.normal.x), .float(vertex.normal.y), .float(vertex.normal.z),
                .uchar(0), .uchar(0), .uchar(0)
            ], to: &s)
        }
        for face in faces {
            let indices = face.map { PlyEncoder.Value.int(Int32($0)) }
            encoder.encodeListElement(indices, to: &s)
        }

        return s
    }
}
