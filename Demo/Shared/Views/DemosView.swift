import Everything
// import GameController
import RenderKit
import simd
import SIMDSupport
import SwiftUI
import RenderKitDemo
import RenderKitSupport
import RenderKitSceneGraph

struct DemosView: View {
    @StateObject
    // swiftlint:disable:next force_try
    var model = try! RenderModel(device: MTLCreateSystemDefaultDevice()!)

    enum Mode: String {
        case render
        case gltfLoaderView
        case fullScreen
        case objectLog
        #if os(macOS)
            case metalInfo
            case consoleLog
        #endif
        case voronoi
    }

    @AppStorage("mode") // TODO: This should be SceneStorage but broken?
    var mode: Mode = .render

    var body: some View {
        Group {
            switch mode {
            case .render:
                MainView()
                    .overlay(alignment: .topLeading) {
                        MapView().environmentObject(model.sceneGraph)
                    }
                #if !os(xrOS)
                    .inspector(isPresented: .constant(true)) {
                        DetailView()
                    }
                #endif
            case .gltfLoaderView:
                GLTFLoaderView()
            case .fullScreen:
                MainView()
            case .objectLog:
                ObjectLogView().frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(macOS)
                case .metalInfo:
                    MetalInfoView()
                case .consoleLog:
                    ConsoleLogView()
            #endif
            case .voronoi:
                VoronoiNoiseComputeView()
            }
        }
        .environmentObject(model)
        .toolbar {
            toolbar()
        }
    }

    @ViewBuilder
    func toolbar() -> some View {
        Button(title: "Add Light", systemImage: "lightbulb.fill", action: { addLight() }).foregroundColor(.yellow)
        Button(title: "Spawn", systemImage: "cube.fill", action: { spawn() }).foregroundColor(.purple)
            .keyboardShortcut(.init("N"), modifiers: .command)

        Picker("Mode", selection: $mode) {
            Text("Render").tag(Mode.render)
            Text("Voronoi").tag(Mode.voronoi)
            #if os(macOS)
                Text("Metal Info").tag(Mode.metalInfo)
                Text("Console Log").tag(Mode.consoleLog)
            #endif
        }
        #if os(macOS)
        .pickerStyle(PopUpButtonPickerStyle())
        #endif
        .controlSize(.small)
    }

    func spawn() {
        do {
            let position = model.sceneGraph.cameraController.absoluteTarget
            let provider = GeometryProvider.shape(shape: .sphere(Sphere(radius: 1)))
            let geometry = try MetalKitGeometry(provider: provider, device: MTLCreateYoloDevice())
            let material = try BlinnPhongMaterial(diffuseColor: [0.5, 0, 0, 1], specularColor: [1, 1, 1, 1], shininess: 16)
            let entity = ModelEntity(transform: Transform(translation: position), selectors: ["teapot"], geometry: geometry, material: material)
            model.sceneGraph.scene.addChild(node: entity)
        }
        catch {
            error.log()
        }
    }

    func addLight() {
        for _ in 0 ..< 100 {
            let position = SIMD3<Float>.random(in: -10 ... 10)
            let color = SIMD3<Float>.random(in: 0 ... 1)
            let light = Light(transform: .init(translation: position), lightColor: color, lightPower: 40)

            model.sceneGraph.scene.addChild(node: light)
        }
    }
}
