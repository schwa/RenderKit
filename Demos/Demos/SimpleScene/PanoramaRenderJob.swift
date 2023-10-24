import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import RenderKit
import Observation
import Everything

class PanoramaRenderJob: RenderJob {
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var mesh: YAMesh?

    var scene: SimpleScene
    var textures: [MTLTexture] = []

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func setup<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws {
        let library = try! device.makeDefaultLibrary(bundle: .shadersBundle)
        let vertexFunction = library.makeFunction(name: "panoramicVertexShader")!
        let constantValues = MTLFunctionConstantValues()
        //constantValues.setConstantValue(<#T##value: UnsafeRawPointer##UnsafeRawPointer#>, type: .ushort, withName: <#T##String#>)

        let fragmentFunction = try library.makeFunction(name: "panoramicFragmentShader", constantValues: constantValues)

        depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor.always())

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
        let descriptor = VertexDescriptor.packed(semantics: [.position, .normal, .textureCoordinate])
        renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(descriptor)
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        if let panorama = scene.panorama {
            mesh = try! panorama.mesh(device)
            let loader = MTKTextureLoader(device: device)
            textures = try panorama.tileTextures.map { try $0(loader) }
        }
    }

    func encode(on encoder: MTLRenderCommandEncoder, size: CGSize) throws {
        guard let renderPipelineState, let depthStencilState else {
            return
        }
        guard let panorama = scene.panorama else {
            return
        }
        encoder.withDebugGroup("Panorama") {
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setDepthStencilState(depthStencilState)

            guard let mesh else {
                fatalError()
            }
            encoder.setVertexBuffers(mesh)
            let cameraUniforms = CameraUniforms(projectionMatrix: scene.camera.projection.matrix(viewSize: SIMD2<Float>(size)))
            let inverseCameraMatrix = scene.camera.transform.matrix.inverse
            encoder.setVertexBytes(of: cameraUniforms, index: 1)
            let modelViewMatrix = inverseCameraMatrix * float4x4.translation(scene.camera.transform.translation)
            encoder.setVertexBytes(of: modelViewMatrix, index: 2)

            let uniforms = PanoramaFragmentUniforms(gridSize: panorama.tilesSize, colorFactor: [1, 1, 1, 1])

            encoder.setFragmentBytes(of: uniforms, index: 0)

            encoder.setFragmentTextures(textures, range: 0..<textures.count)
            //encoder.setTriangleFillMode(.fill)

            encoder.draw(mesh)
        }
    }
}
