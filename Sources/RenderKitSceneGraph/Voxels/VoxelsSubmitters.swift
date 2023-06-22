import Everything
import MetalKit
import Shaders
import simd
import SIMDSupport
import RenderKit
import RenderKitSupport

// NOTE: MOST OF THIS IS DUPLICATE CODE
public class VoxelsSubmitters: RenderSubmitter {
    public var camera: Camera
    public var lightingModel: BlinnPhongLightingModel

//    @MainActor
    public var voxelModel: VoxelModel?

    public init(model: VoxelModel, camera: Camera, lightingModel: BlinnPhongLightingModel) {
        self.voxelModel = model
        self.camera = camera
        self.lightingModel = lightingModel

        // swiftlint:disable force_try
//        Task {
//            }
//        }
        // swiftlint:enable force_try
    }

    public func setup(state: inout RenderState) throws {
    }

    public func shouldSubmit(pass: some RenderPassProtocol, environment: RenderEnvironment) -> Bool {
        true
    }

    public func prepareRender(pass: some RenderPassProtocol, state: inout RenderState, environment: inout RenderEnvironment) throws {
        guard pass.selectors.contains("voxel") else {
            return
        }
        try lightingModel.setup(state: &state)
        environment.update(try lightingModel.parameterValues())
    }

    public func submit(pass: some RenderPassProtocol, state: RenderState, environment: inout RenderEnvironment, commandEncoder: MTLRenderCommandEncoder) throws {
        guard pass.selectors.contains("voxel"), let voxelModel else {
            return
        }

        let drawableSize = state.drawableSize
        let aspectRatio = Float(drawableSize.width / drawableSize.height)
        let projectionTransform = camera.projection._matrix(aspectRatio: aspectRatio)
        let viewTransform = camera.transform.matrix.inverse

        commandEncoder.pushDebugGroup("VOXELS")

        let modelTransform = Transform(rotation: simd_quatf(angle: degreesToRadians(270), axis: [1, 0, 0]), translation: [5, +0.1, -5]).matrix
        var transforms = Transforms()
        transforms.modelView = viewTransform * modelTransform
        transforms.modelNormal = simd_float3x3(truncating: modelTransform).transpose.inverse
        transforms.projection = projectionTransform
        environment["$VERTICES"] = .buffer(voxelModel.vertexBuffer, offset: 0)
        environment["$TRANSFORMS"] = .accessor(UnsafeBytesAccessor(transforms))
        environment["$VOXEL_COLOR_PALETTE"] = .texture(voxelModel.colorPalette)
        try commandEncoder.set(environment: environment, forPass: pass)

        commandEncoder.draw(voxel: voxelModel)

        commandEncoder.popDebugGroup()
    }
}
