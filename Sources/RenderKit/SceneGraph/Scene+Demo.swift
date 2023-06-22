import Metal
import MetalKit
import ModelIO

import Everything

private extension ModelEntity {
    convenience init(color: SIMD4<Float>, _ meshBuilder: () throws -> MTKMesh) rethrows {
        let mesh = try meshBuilder()
        self.init(mesh: mesh, color: color)
    }
}

public extension Scene {
    static func demoSceneGraph(device: MTLDevice) throws -> Scene {
        let sceneGraph = Scene()

        let camera = PerspectiveCamera(fovy: degreesToRadians(30), near: 1, far: 200)
        camera.name = "Camera"
        camera.transform.translation = [0, 0, -100]
        sceneGraph.currentCamera = camera
        sceneGraph.rootNode.addChild(camera)

        let allocator = MTKMeshBufferAllocator(device: device)

        let sphereNode = try ModelEntity(color: [1, 0, 0, 1]) {
            let mdlMesh = MDLMesh.newEllipsoid(withRadii: [10, 10, 10], radialSegments: 12, verticalSegments: 12, geometryType: .triangles, inwardNormals: false, hemisphere: false, allocator: allocator)
            return try MTKMesh(mesh: mdlMesh, device: device)
        }
        sphereNode.name = "Sphere"
        sphereNode.transform.translation = [0, 5, 0]
        sphereNode.material.diffuseColor = [0, 1, 0]
        sceneGraph.rootNode.addChild(sphereNode)

        let cubeNode = try ModelEntity(color: [0, 1, 0, 1]) {
            let mdlMesh = MDLMesh.newBox(withDimensions: [20, 20, 20], segments: [8, 8, 8], geometryType: .triangles, inwardNormals: false, allocator: allocator)
            return try MTKMesh(mesh: mdlMesh, device: device)
        }
        cubeNode.name = "Cube"
        cubeNode.transform.translation = [-25, 5, 0]
        cubeNode.material.diffuseColor = [0, 0, 1]
        sceneGraph.rootNode.addChild(cubeNode)
        return sceneGraph
    }
}
