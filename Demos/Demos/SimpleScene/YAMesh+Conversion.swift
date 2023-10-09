import RenderKit

extension YAMesh {
    func convert(to other: VertexDescriptor) throws -> YAMesh {
        if vertexDescriptor == other {
            return self
        }

        fatalError()
    }
}
