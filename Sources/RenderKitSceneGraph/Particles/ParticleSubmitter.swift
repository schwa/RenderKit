import Foundation
import Metal
import RenderKit
import RenderKitSupport
import Shaders
import SIMDSupport
import SwiftUI

public class ParticleSystem {
    public let particleCount: Int
    public let particles: MTLBuffer
    public let particlesEnvironment: MTLBuffer

    public init(device: MTLDevice) {
        let particleCount = 10000
        let particles = device.makeBuffer(length: particleCount * MemoryLayout<Particle>.stride)!
        particles.withEx(type: Particle.self, count: particleCount) { buffer in
            for n in 0 ..< particleCount {
                //                buffer[n].position = [.random(in: -5...5), .random(in: 0...10), .random(in: -5...5)]
                buffer[n].position = .zero
                buffer[n].oldPosition = buffer[n].position

                let q = simd_quatf(angle: .randomDegrees(in: 270 ... 360 + 90), axis: [1, 0, 0])
                    * simd_quatf(angle: .randomDegrees(in: 270 ... 360 + 90), axis: [0, 0, 1])

                buffer[n].acceleration = q.act([0, 2000, 0])
                buffer[n].age = Float.random(in: 0 ... 5)
                buffer[n].lifetime = 5
            }
        }

        let particlesEnvironment = device.makeBuffer(length: MemoryLayout<ParticlesEnvironment>.size)!
        particlesEnvironment.withEx(type: ParticlesEnvironment.self, count: 1) { buffer in
            buffer[0].gravity = [0, -9.8, 0]
            buffer[0].timestep = 1 / 120
        }

        self.particleCount = particleCount
        self.particles = particles
        self.particlesEnvironment = particlesEnvironment
    }
}

public class ParticleSubmitter: RenderSubmitter {
    var particleSystem: ParticleSystem
    var geometry: MetalKitGeometry?

    let scene: SceneGraph

    public init(scene: SceneGraph, particleSystem: ParticleSystem) {
        self.scene = scene
        self.particleSystem = particleSystem
    }

    public func setup(state: inout RenderState) throws {
        let device = state.device
        geometry = try MetalKitGeometry(provider: .shape(shape: .box(Box(extent: [0.1, 0.1, 0.1], segments: [1, 1, 1], inwardNormals: false))), device: device)
    }

    public func shouldSubmit(pass: some RenderPassProtocol, environment: RenderEnvironment) -> Bool {
        pass.selectors.contains("particles")
    }

    public func prepareRender(pass: some RenderPassProtocol, state: inout RenderState, environment: inout RenderEnvironment) throws {
        guard pass.selectors.contains("particles") else {
            return
        }
        environment["$PARTICLES"] = .buffer(particleSystem.particles, offset: 0)
        environment["$PARTICLES_ENVIRONMENT"] = .buffer(particleSystem.particlesEnvironment, offset: 0)
    }

    public func submit(pass: some RenderPassProtocol, state: RenderState, environment: inout RenderEnvironment, commandEncoder: MTLRenderCommandEncoder) throws {
        guard pass.selectors.contains("particles") else {
            return
        }
        guard let geometry else {
            return
        }

        let drawableSize = state.targetTextureSize
        let aspectRatio = Float(drawableSize.width / drawableSize.height)
        let projectionTransform = scene.camera.projection._matrix(aspectRatio: aspectRatio)
        let viewTransform = scene.camera.transform.matrix.inverse
        let modelTransform = Transform(translation: [1.5, 0, 0]).matrix
        var transforms = Transforms()
        transforms.modelView = viewTransform * modelTransform
        transforms.modelNormal = simd_float3x3(truncating: modelTransform).transpose.inverse
        transforms.projection = projectionTransform
        environment["$TRANSFORMS"] = .accessor(UnsafeBytesAccessor(transforms))
        environment["$VERTICES"] = .buffer(geometry.mesh.vertexBuffers[0].buffer, offset: geometry.mesh.vertexBuffers[0].offset)

        assert(geometry.mesh.submeshes.count == 1)
        let submesh = geometry.mesh.submeshes[0]

        try commandEncoder.set(environment: environment, forPass: pass)

        commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset, instanceCount: particleSystem.particleCount, baseVertex: 0, baseInstance: 0)
    }
}
