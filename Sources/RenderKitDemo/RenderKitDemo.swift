import Combine
import Everything
import MetalKit
import MetalSupport
import RenderKit
import Shaders
import simd
import SIMDSupport
import SwiftUI
import RenderKitSupport
import RenderKitSceneGraph
import Foundation
import Metal

public class RenderModel: ObservableObject {
    public let device: MTLDevice
    public let sceneGraph: SceneGraph
    public let renderer: Renderer<DemoRenderGraph>

    @Atomic
    static var cachedArray: [UInt8]?

    var frameStateBuffer: MTLBuffer

    public init(device: MTLDevice) throws {
        sceneGraph = try SceneGraph.demo()
        let graph = DemoRenderGraph()

        self.device = device

        let width = 1024
        let height = 1024

        let inputArray: [UInt8]
        if let cachedArray = RenderModel.cachedArray {
            inputArray = cachedArray
        }
        else {
            inputArray = (0 ... width * height).map { _ in
                UInt8.random(in: 0 ... 1) * 255
            }
            RenderModel.cachedArray = inputArray
        }
        assertNotInRenderLoop()
        let inputTexture = device.makeTexture2D(width: width, height: height, pixelFormat: .r8Uint, storageMode: .private, usage: [.shaderRead, .shaderWrite], pixels: inputArray, label: "LIFE_A")

        let outputArray = Array(repeating: UInt8(0), count: width * height)
        assertNotInRenderLoop()
        let outputTexture = device.makeTexture2D(width: width, height: height, pixelFormat: .r8Uint, storageMode: .private, usage: [.shaderRead, .shaderWrite], pixels: outputArray, label: "LIFE_B")

        let color = try MaterialParameter(color: [0, 1, 1, 1], device: device, label: "$TEST_TEXTURE")

        var frameState = FrameState()
        frameState.time = Float(CFAbsoluteTimeGetCurrent())
        frameState.frame = 0
        frameState.desiredFPS = 120 // HACK: fixme
        frameState.screenGamma = 2.2
        frameStateBuffer = device.makeBuffer(bytesOf: frameState, options: [])!

        // NOTE: this is getting messier

        let particleSystem = ParticleSystem(device: device)

        // NOTE: Hard coded. This needs to be generated syntheticly
        let environment: [RenderEnvironment.Key: ParameterValue] = [
            "$TEST_TEXTURE": .texture(color.texture),
            "$TEST_SAMPLER": .samplerState(color.samplerState),
            "$INPUT_TEXTURE": .texture(inputTexture),
            "$OUTPUT_TEXTURE": .texture(outputTexture),
            "$DEBUG_MODE": .accessor(UnsafeBytesAccessor(3)),
            "$FRAME_STATE": .buffer(frameStateBuffer, offset: 0),
            "$PARTICLES": .buffer(particleSystem.particles, offset: 0),
            "$PARTICLES_ENVIRONMENT": .buffer(particleSystem.particlesEnvironment, offset: 0),
        ]

        let particleSubmitter = ParticleSubmitter(scene: sceneGraph, particleSystem: particleSystem)

        renderer = Renderer(device: device, graph: graph, environment: environment)
        renderer.add(submitter: SceneGraphRenderSubmitter(scene: sceneGraph))
        renderer.add(submitter: FullScreenRenderSubmitter())

        let voxelModel = try VoxelModel(model: try MagicaVoxelModel(named: "monu7", bundle: .module))


        renderer.add(submitter: VoxelsSubmitters(model: voxelModel, camera: sceneGraph.camera, lightingModel: sceneGraph.lightingModel))
        renderer.add(submitter: particleSubmitter)
        renderer.events.sink { [weak self] _ in
            self?.swapLifeTextures()

            self?.frameStateBuffer.with(type: FrameState.self) { frameState in
                frameState.time = Float(CFAbsoluteTimeGetCurrent())
                frameState.frame += 1
            }
        }
        .store(in: &cancellables)
    }

    func swapLifeTextures() {
        let a = renderer.environment["$INPUT_TEXTURE"]
        let b = renderer.environment["$OUTPUT_TEXTURE"]
        renderer.environment["$INPUT_TEXTURE"] = b
        renderer.environment["$OUTPUT_TEXTURE"] = a
    }

    var cancellables: Set<AnyCancellable> = []
}

public struct DemoRenderGraph: RenderGraphProtocol {
    public let passes: [any PassProtocol] = [
        LifeComputePass(),
        BlinnPhongRenderPass(),
        GameOfLifeRenderPass(),
        VoxelRenderPass(),
        DebugVisualizerPass(),
        WireframePass(),
        ParticleUpdatePass(),
        ParticleRenderPass(),
    ]

    public init() {
    }
}

public extension SceneGraph {
    static func demo() throws -> SceneGraph {
        let device = MTLCreateYoloDevice()

        let camera = Camera(projection: .perspective(Perspective(fovy: .degrees(60), near: 0.1, far: 1000)))
        let cameraController = CameraController(position: [0, 1, 5], target: [0, 0, -1], camera: camera)
        let lightingModel = BlinnPhongLightingModel(lights: [
            Light(transform: .translation([-5, 2, 5]), lightColor: [0, 0, 0.5], lightPower: 40),
            Light(transform: .translation([5, 5, 5]), lightColor: [0, 1, 0], lightPower: 40),
        ])

        let scene = SceneNode(name: "root", children: [
            try ModelEntity(name: "teapot", transform: Transform(scale: [0.5, 0.5, 0.5], rotation: simd_quatf(real: 0.707_106_828_689_575, imag: [0, 0.707_106_769_084_93, 0]), translation: [-1, 0, 0]), selectors: ["teapot"], geometry: MetalKitGeometry(named: "teapot", device: device), material: BlinnPhongMaterial(diffuseColor: [0.5, 0, 0, 1], specularColor: [1, 1, 1, 1], shininess: 16)),
            try ModelEntity(isHidden: true, transform: .translation([-4, 0, -1]), geometry: MetalKitGeometry(provider: .shape(shape: .plane(Plane(extent: [10, 0, 10], segments: [1, 1]))), device: device), material: UnlitMaterial(baseColor: [1, 0, 0, 1])),
            try ModelEntity(name: "plane", selectors: ["plane"], geometry: MetalKitGeometry(shape: .plane(Plane(extent: [10, 0, 10])), device: device), material: nil),
            try ModelEntity(name: "plane", transform: .translation([0, 5, -5]).rotated(angle: .degrees(180), axis: [0, 1, 0]), selectors: ["plane"], geometry: MetalKitGeometry(shape: .plane(Plane(extent: [10, 10, 0])), device: device), material: nil),

            try ModelEntity(name: "skybox", transform: .translation([0, 0.5, 0]), selectors: ["teapot"], geometry: MetalKitGeometry(provider: .shape(shape: .sphere(Sphere(extent: [1, 1, 1], segments: [24, 24], inwardNormals: false))), device: device), material: BlinnPhongMaterial(ambient: .init(named: "Road_to_MonumentValley_8k", bundle: .module, device: device), diffuse: .color([0, 0, 0, 0]), specular: .color([0.5, 0.5, 0.5, 1]), shininess: 16)),

            ParticleNode(),
            camera,
        ])

        let sceneGraph = SceneGraph(cameraController: cameraController, camera: camera, scene: scene, lightingModel: lightingModel)
        return sceneGraph
    }
}

