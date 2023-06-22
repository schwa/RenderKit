import Everything
import MetalKit
import Shaders
import simd
import RenderKitSupport

public class FullScreenRenderSubmitter: RenderSubmitter {
    let indexBuffer: MTLBuffer
    let vertexBuffer: MTLBuffer
    let transforms: Transforms

    public init(device: MTLDevice) {

        var transforms = Transforms()
        transforms.modelView = .identity
        transforms.modelNormal = .identity
        transforms.projection = .identity
        self.transforms = transforms

        let vertices: [Float] = [
            -1, -1, 0, 0, 0, 1, 0, 0,
            1, -1, 0, 0, 0, 1, 1, 0,
            1, 1, 0, 0, 0, 1, 1, 1,
            -1, 1, 0, 0, 0, 1, 0, 1,
        ]
        let indices: [UInt16] = [
            0, 1, 2,
            0, 2, 3,
        ]

        let vertexBuffer = vertices.withUnsafeBytes {
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
        }
        vertexBuffer.label = "Fullscreen Vertex Buffer"
        self.vertexBuffer = vertexBuffer

        let indexBuffer = indices.withUnsafeBytes {
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
        }
        indexBuffer.label = "Fullscreen Index Buffer"
        self.indexBuffer = indexBuffer
    }

    public func setup(state: inout RenderState) throws {
    }

    public func shouldSubmit(pass: some RenderPassProtocol, environment: RenderEnvironment) -> Bool {
        pass.selectors.contains("full_screen")
    }

    public func prepareRender(pass: some RenderPassProtocol, state: inout RenderState, environment: inout RenderEnvironment) throws {
    }

    public func submit(pass: some RenderPassProtocol, state: RenderState, environment: inout RenderEnvironment, commandEncoder: MTLRenderCommandEncoder) throws {
        guard pass.selectors.contains("full_screen") else {
            fatalError("Should not get here")
        }

        environment.update([
            "$VERTICES": .buffer(vertexBuffer, offset: 0),
            "$TRANSFORMS": .accessor(UnsafeBytesAccessor(transforms)),
        ])

        try commandEncoder.set(environment: environment, forPass: pass)

        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}
