import SwiftUI
import ModelIO
import Metal
import MetalKit
import SIMDSupport
import RenderKitShaders
import RenderKit
import Observation
import Everything

protocol SceneRenderJob: RenderJob {
    var scene: SimpleScene { get set }
}

class SimpleSceneRenderPass: RenderPass {
    var scene: SimpleScene {
        didSet {
            renderJobs.forEach { job in
                job.scene = scene
            }
        }
    }
    var renderJobs: [any RenderJob & SceneRenderJob] = []

    init(scene: SimpleScene) {
        self.scene = scene
    }

    func setup<Configuration: MetalConfiguration>(device: MTLDevice, configuration: inout Configuration) throws {
        if let panorama = scene.panorama {
            let job = PanoramaRenderJob(scene: scene, panorama: panorama)
            job.scene = scene
            self.renderJobs.append(job)
        }

        let flatModels = scene.models.filter { ($0.material as? FlatMaterial) != nil }
        if !flatModels.isEmpty {
            let job = FlatMaterialRenderJob(scene: scene, models: flatModels)
            self.renderJobs.append(job)
        }

        let unlitModels = scene.models.filter { ($0.material as? UnlitMaterial) != nil }
        if !unlitModels.isEmpty {
            let job = UnlitMaterialRenderJob(scene: scene, models: unlitModels)
            self.renderJobs.append(job)
        }

        try self.renderJobs.forEach { job in
            try job.setup(device: device, configuration: &configuration)
        }
    }

    func draw(device: MTLDevice, size: CGSize, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) throws {
        try commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
            encoder.label = "SimpleJobsBasedRenderPass-RenderCommandEncoder"
            try renderJobs.forEach { job in
                try job.encode(on: encoder, size: size)
            }
        }
    }
}

// MARK: -
