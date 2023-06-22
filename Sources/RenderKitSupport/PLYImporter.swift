// import Everything
// import Foundation
// import Metal
//
//// http://gamma.cs.unc.edu/POWERPLANT/papers/ply.pdf
//
// public func plyImporter(url: URL, device: MTLDevice) throws -> Geometry {
//    let string = try String(contentsOf: url)
//
//    let scanner = Scanner(string: string)
//
//    try scanner.scanString("ply").safelyUnwrap(PLYImporterError.generic("Oops"))
//    try scanner.scanString("format ascii 1.0").safelyUnwrap(PLYImporterError.generic("Oops"))
//
//    struct Element {
//        let name: String
//        let count: Int
//        var properties: [Property]
//    }
//
//    struct Property {
//        let type: String
//        let name: String
//    }
//
//    let keyword = CharacterSet.letters.union( CharacterSet(charactersIn: "_"))
//
//    var elements: [Element] = []
//
//    while !scanner.isAtEnd && scanner.scanString("end_header") == nil {
//        if scanner.scanString("comment") != nil {
//            _ = scanner.scanUpToCharacters(from: .newlines)
//        }
//        if scanner.scanString("element") != nil {
//            let name = try scanner.scanCharacters(from: keyword).safelyUnwrap(PLYImporterError.generic("Oops"))
//            let count = try scanner.scanInt().safelyUnwrap(PLYImporterError.generic("Oops"))
//            let element = Element(name: name, count: count, properties: [])
//            elements.append(element)
//        }
//        if scanner.scanString("property") != nil {
//            let type = try scanner.scanCharacters(from: keyword).safelyUnwrap(PLYImporterError.generic("Oops"))
//            switch type {
//            case "list":
//                /* let indexType = */try scanner.scanCharacters(from: keyword).safelyUnwrap(PLYImporterError.generic("Oops"))
//                /* let elementType = */try scanner.scanCharacters(from: keyword).safelyUnwrap(PLYImporterError.generic("Oops"))
//            default:
//                break
//            }
//            let name = try scanner.scanCharacters(from: keyword).safelyUnwrap(PLYImporterError.generic("Oops"))
//            let property = Property(type: type, name: name)
//            elements[elements.count - 1].properties.append(property)
//        }
//    }
//
//    var elementValues: [String: [[String: Any]]] = [:]
//
//    for element in elements {
//        let values = try (0..<element.count).map { _ -> [String: Any] in
//            var d: [String: Any] = [:]
//            for property in element.properties {
//                switch property.type {
//                case "float":
//                    let f = try scanner.scanFloat().safelyUnwrap(PLYImporterError.generic("Oops"))
//                    d[property.name] = f
//                case "uchar":
//                    let f = UInt8(try scanner.scanInt().safelyUnwrap(PLYImporterError.generic("Oops")))
//                    d[property.name] = f
//                case "list":
//                    let count = try scanner.scanInt().safelyUnwrap(PLYImporterError.generic("Oops"))
//                    let values = try (0..<count).map { _ in
//                        try scanner.scanInt().safelyUnwrap(PLYImporterError.generic("Oops"))
//                    }
//                    d[property.name] = values
//                default:
//                    fatalError("")
//                }
//            }
//            return d
//        }
//        elementValues[element.name, default: []].append(contentsOf: values)
//    }
//
//    let vertices = elementValues["vertex"]!.map { d -> Vertex in
//        let position: [Float] = ["x", "y", "z"].map { d[$0] as! Float }
//        let normal: [Float] = ["nx", "ny", "nz"].map { d[$0] as! Float }
//        let textureCoordinate: [Float] = ["s", "t"].map { d[$0] as! Float }
//        return Vertex(position: SIMD3<Float>(position), normal: SIMD3<Float>(normal), textureCoordinate: SIMD2<Float>(textureCoordinate))
//    }
//    let vertexBuffer = vertices.withUnsafeBytes {
//        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: [])
//    }
//
//    let indices: [[UInt16]] = elementValues["face"]!.map { d -> [UInt16] in
//        (d["vertex_indices"]! as! [Int]).map { UInt16($0) }
//    }
//    assert(indices.contains(where: { $0.count != indices.first!.count }) == false)
//    let flatIndices = indices.flatMap({ $0 })
//    let indexBuffer = flatIndices.withUnsafeBytes {
//        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: [])
//    }
//
//    let geometry = Geometry(vertexBuffer: vertexBuffer!, indexBuffer: indexBuffer!, indexCount: flatIndices.count, indexType: .uint16, primitiveType: .triangle, mesh: nil)
//    return geometry
// }
//
// enum PLYImporterError: Error {
//    case generic(String)
// }
//
// let cube = """
// ply
// format ascii 1.0
// comment Created by Blender 3.0.0 - www.blender.org
// element vertex 24
// property float x
// property float y
// property float z
// property float nx
// property float ny
// property float nz
// property float s
// property float t
// element face 12
// property list uchar uint vertex_indices
// end_header
// -0.500000 0.500000 0.500000 0.000000 0.000000 1.000000 0.875000 0.500000
// 0.500000 -0.500000 0.500000 0.000000 0.000000 1.000000 0.625000 0.750000
// 0.500000 0.500000 0.500000 0.000000 0.000000 1.000000 0.625000 0.500000
// 0.500000 -0.500000 0.500000 0.000000 -1.000000 0.000000 0.625000 0.750000
// -0.500000 -0.500000 -0.500000 0.000000 -1.000000 0.000000 0.375000 1.000000
// 0.500000 -0.500000 -0.500000 0.000000 -1.000000 0.000000 0.375000 0.750000
// -0.500000 -0.500000 0.500000 -1.000000 0.000000 0.000000 0.625000 0.000000
// -0.500000 0.500000 -0.500000 -1.000000 0.000000 0.000000 0.375000 0.250000
// -0.500000 -0.500000 -0.500000 -1.000000 0.000000 0.000000 0.375000 0.000000
// 0.500000 0.500000 -0.500000 0.000000 0.000000 -1.000000 0.375000 0.500000
// -0.500000 -0.500000 -0.500000 0.000000 0.000000 -1.000000 0.125000 0.750000
// -0.500000 0.500000 -0.500000 0.000000 0.000000 -1.000000 0.125000 0.500000
// 0.500000 0.500000 0.500000 1.000000 0.000000 -0.000000 0.625000 0.500000
// 0.500000 -0.500000 -0.500000 1.000000 0.000000 -0.000000 0.375000 0.750000
// 0.500000 0.500000 -0.500000 1.000000 0.000000 -0.000000 0.375000 0.500000
// -0.500000 0.500000 0.500000 0.000000 1.000000 -0.000000 0.625000 0.250000
// 0.500000 0.500000 -0.500000 0.000000 1.000000 -0.000000 0.375000 0.500000
// -0.500000 0.500000 -0.500000 0.000000 1.000000 -0.000000 0.375000 0.250000
// -0.500000 -0.500000 0.500000 0.000000 -0.000000 1.000000 0.875000 0.750000
// -0.500000 -0.500000 0.500000 0.000000 -1.000000 0.000000 0.625000 1.000000
// -0.500000 0.500000 0.500000 -1.000000 0.000000 0.000000 0.625000 0.250000
// 0.500000 -0.500000 -0.500000 0.000000 0.000000 -1.000000 0.375000 0.750000
// 0.500000 -0.500000 0.500000 1.000000 0.000000 0.000000 0.625000 0.750000
// 0.500000 0.500000 0.500000 0.000000 1.000000 -0.000000 0.625000 0.500000
// 3 0 1 2
// 3 3 4 5
// 3 6 7 8
// 3 9 10 11
// 3 12 13 14
// 3 15 16 17
// 3 0 18 1
// 3 3 19 4
// 3 6 20 7
// 3 9 21 10
// 3 12 22 13
// 3 15 23 16
// """
