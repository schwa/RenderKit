// swiftlint:disable indentation_width

import Everything
import MetalKit
import SceneKit

public extension Entity {
    func convert() throws -> SCNNode? {
        let scnNode = SCNNode()
        scnNode.name = name
        switch transform.storage {
        case .matrix(let matrix):
            scnNode.simdTransform = matrix
        case .srt(let srt):
            scnNode.simdScale = srt.scale
            scnNode.simdRotation = srt.rotation.vector
            scnNode.simdPosition = srt.translation
        }
        switch self {
        case _ as PerspectiveCamera:
            let camera = SCNCamera()
            scnNode.camera = camera
        case let node as ModelEntity:
            scnNode.geometry = node.mesh.asSCNGeometry
//            let ply = node.mesh.toPLY()
//
//            try ply.write(to: URL(fileURLWithPath: "/Users/schwa/Desktop/model.ply"), atomically: true, encoding: .utf8)

//            scnNode.geometry!.materials[0].diffuse.contents = node.color.cgColor
//            scnNode.geometry!.materials[0].ambient.contents = node.color.cgColor
        default:
            break
        }
        for child in children {
            if let child = try child.convert() {
                scnNode.addChildNode(child)
            }
        }
        return scnNode
    }
}

public extension MTKMesh {
    var asSCNGeometry: SCNGeometry {
        unimplemented()
//        let stride = (vertexDescriptor.layouts[0] as! MDLVertexBufferLayout).stride
//        let attributes = vertexDescriptor.attributes.map { $0 as! MDLVertexAttribute }.filter { $0.format != .invalid }
//        let sources = attributes.compactMap { attribute -> SCNGeometrySource? in
//            let buffer = vertexBuffers[attribute.bufferIndex]
//            let semantic: SCNGeometrySource.Semantic
//            switch attribute.name {
//            case "position":
//                semantic = .vertex
//            case "normal":
//                semantic = .normal
//            case "textureCoordinate":
//                semantic = .texcoord
//            default:
//                warning(false, "Unknown buffer name: \(buffer.name)")
//                return nil
//            }
//            return SCNGeometrySource(buffer: buffer.buffer, vertexFormat: MTLVertexFormat(attribute.format), semantic: semantic, vertexCount: buffer.length / stride, dataOffset: buffer.offset, dataStride: stride)
//        }
//        let elements: [SCNGeometryElement] = submeshes.map { submesh in
//            assert(submesh.indexBuffer.type == .index)
//            let data = submesh.indexBuffer.buffer.data()
//            assert(data.count == submesh.indexCount * submesh.indexType.indexSize)
//            guard let vertexCountPerPrimitive = submesh.primitiveType.vertexCount else {
//                fatalError("No vertex count")
//            }
//            let primitiveCount = submesh.indexCount / vertexCountPerPrimitive
//            return SCNGeometryElement(data: data, primitiveType: SCNGeometryPrimitiveType(submesh.primitiveType), primitiveCount: primitiveCount, bytesPerIndex: submesh.indexType.indexSize)
//        }
//        return SCNGeometry(sources: sources, elements: elements)
    }
}
