import Everything
import MetalKit

// TODO: Move

//public extension MTKMesh {
//    func toPLY() -> String {
//        let layout = StructureLayout(vertexDescriptor)
//
//        assert(vertexBuffers.count == 1)
//        let data = vertexBuffers[0].buffer.data()
//        let accessor = Accessor<Data, DynamicRow>(layout: layout, storage: data)
//        let positions = accessor.map { $0["position"] as SIMD3<Float> }
//        let normals = accessor.map { $0["normal"] as SIMD3<Float> }
//        let textureCoordinates = accessor.map { $0["textureCoordinate"] as SIMD2<Float> }
//        assert(submeshes.count == 1)
//        let submesh = submeshes[0]
//        let indexData = submesh.indexBuffer.buffer.data()
//        assert(submesh.indexType == .uint16)
//        let indices = indexData.withUnsafeBytes { buffer -> [Int] in
//            let indices = buffer.bindMemory(to: UInt16.self)
//            return indices.map { Int($0) }
//        }
//        .chunks(of: 3) // TODO: Hardcoded
//        return plyExporter(vertices: positions, normals: normals, textureCoordinates: textureCoordinates, indices: Array(indices))
//    }
//}
