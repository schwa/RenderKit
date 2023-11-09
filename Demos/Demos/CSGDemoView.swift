import SwiftUI
import RenderKitScratch
import RenderKit
import RenderKitShaders
import Everything

struct CSGDemoView: View {
    let a: CSG<SimpleVertex>
    let b: CSG<SimpleVertex>
    let c: CSG<SimpleVertex>

    init() {
        a = Box(min: [-5, -5, -5], max: [5, 5, 5]).toCSG()
        b = Box(min: [-7.5, -7.5, -5], max: [2.5, 2.5, 5]).toCSG()

        c = a.union(b)

        try! a.inverted().toPLY().write(to: URL(filePath: "test-a.ply"), atomically: true, encoding: .ascii)
        try! b.toPLY().write(to: URL(filePath: "test-b.ply"), atomically: true, encoding: .ascii)
        try! c.toPLY().write(to: URL(filePath: "test-c.ply"), atomically: true, encoding: .ascii)

        URL(filePath: "test-c.ply").reveal()

        //        let plane = Plane(normal: [0, 1, 0], w: 5)
//        let csg = sphere.toCSG()
//        print(csg.polygons.count)
//        let (a, b) = csg.split(plane: plane)
//        print(a.polygons.count)
//        print(b.polygons.count)
//        print(a.polygons.count + b.polygons.count)
    }

    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(scale: 30)
            context.translateBy(x: size.width / 2, y: size.height / 2)
//            context.draw(csg: a, transform: transform, with: .color(.red))
//            context.draw(csg: b, transform: transform, with: .color(.green))
            context.draw(csg: c, transform: transform, with: .color(.blue))
        }
    }
}

extension GraphicsContext {
    func draw <V>(csg: CSG<V>, transform: CGAffineTransform = .identity, with shading: Shading) where V: VertexLike {
        for polygon in csg.polygons {
            let a = polygon.vertices[0].position
            let b = polygon.vertices[1].position
            let c = polygon.vertices[2].position
            let dir = simd_normalize(simd_cross(b - a, c - a))
            guard dir.z > 0 else {
                continue
            }
            let lines = polygon.vertices.map { CGPoint($0.position.xy) }
            let path = Path { path in
                path.addLines(lines)
                path.closeSubpath()
            }
            .applying(transform)
            stroke(path, with: shading)
        }
    }
}

extension URL {
    func reveal() {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
