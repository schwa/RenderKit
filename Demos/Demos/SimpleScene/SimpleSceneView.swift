#if !os(visionOS)
@preconcurrency import Metal
import RenderKit
import SwiftUI
import MetalKit
import ModelIO
import Algorithms
import Observation
import Everything
import SIMDSupport
import SwiftFormats
import SwiftFields
import UniformTypeIdentifiers
import CoreImage
import CoreGraphicsSupport
import AsyncAlgorithms

struct CoreSimpleSceneView: View {
    @Environment(\.metalDevice)
    var device

    @Binding
    var scene: SimpleScene

    @State
    var renderPass: SimpleJobsBasedRenderPass

    @State
    var sceneRenderJob: SimpleSceneModelsRenderJob

    init(scene: Binding<SimpleScene>) {
        self._scene = scene
        let sceneRenderJob = SimpleSceneModelsRenderJob(scene: scene.wrappedValue)
        self.sceneRenderJob = sceneRenderJob
        self.renderPass = SimpleJobsBasedRenderPass(jobs: [
            sceneRenderJob,
        ])
    }

    var body: some View {
        RendererView(renderPass: $renderPass)
            .onChange(of: scene.camera) {
                sceneRenderJob.scene = scene
            }
            .onChange(of: scene.light) {
                sceneRenderJob.scene = scene
            }
            .onChange(of: scene.ambientLightColor) {
                sceneRenderJob.scene = scene
            }
    }
}

// MARK: -

public struct SimpleSceneView: View {
    @Environment(\.metalDevice)
    var device

    @State
    var scene: SimpleScene

#if os(macOS)
    @State
    var isInspectorPresented = true
#else
    @State
    var isInspectorPresented = false
#endif

    @State
    var exportImage: Image?

    init() {
        let device = MTLCreateSystemDefaultDevice()!
        scene = try! SimpleScene.demo(device: device)
    }

    public var body: some View {
        CoreSimpleSceneView(scene: $scene)
#if os(macOS)
        .firstPersonInteractive(camera: $scene.camera)
        .displayLink(DisplayLink2())
        .showFrameEditor()
#endif
        .overlay(alignment: .bottomTrailing, content: mapView)
        .inspector(isPresented: $isInspectorPresented, content: inspector)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                snapshot()
            }
        }
    }

    func mapView() -> some View {
        SimpleSceneMapView(scene: $scene)
            .border(Color.red)
            .frame(width: 200, height: 200)
            .padding()
    }

    func inspector() -> some View {
        MyTabView(scene: $scene)
            .inspectorColumnWidth(ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(title: "Show/Hide Inspector", systemImage: "sidebar.trailing") {
                        isInspectorPresented.toggle()
                    }
                }
            }
    }

    func snapshot() -> some View {
        ValueView(value: false) { isPresentedBinding in
            Button(title: "Snapshot", systemImage: "camera") {
                let scene = scene
                Task {
                    fatalError()
//                    let renderPass = SimpleJobsBasedRenderPass<OffscreenRenderPassConfiguration>(scene: scene)
//                    self.exportImage = Image(cgImage: try await renderPass.snapshot(device: device, size: [1024, 768]))
                }
            }
            .fileExporter(isPresented: isPresentedBinding, item: exportImage, contentTypes: [.png, .jpeg]) { _ in
                exportImage = nil
            }
            .fileExporterFilenameLabel("Snapshot")
        }
    }
}

// MARK: -

struct MyTabView: View {
    enum Tab: Hashable {
        case inspector
        case counters
    }

    @State
    var tab: Tab = .inspector

    @Binding
    var scene: SimpleScene

    var body: some View {
        VStack {
            Picker("Picker", selection: $tab) {
                Image(systemName: "slider.horizontal.3").tag(Tab.inspector)
                Image(systemName: "tablecells").tag(Tab.counters)
            }
            .labelsHidden()
            .fixedSize()
            .pickerStyle(.palette)
            Divider()
            switch tab {
            case .inspector:
                Group {
                    SimpleSceneInspector(scene: $scene)
                        .controlSize(.small)
                }
            case .counters:
                CountersView()
            }
        }
    }
}
#endif
