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
    var renderPass: SimpleSceneRenderPass

    init(scene: Binding<SimpleScene> = .constant(.demo())) {
        self._scene = scene
        self.renderPass = SimpleSceneRenderPass(scene: scene.wrappedValue)
    }

    var body: some View {
        RendererView(renderPass: $renderPass)
            .onChange(of: scene.camera) {
                renderPass.scene = scene
            }
            .onChange(of: scene.light) {
                renderPass.scene = scene
            }
            .onChange(of: scene.ambientLightColor) {
                renderPass.scene = scene
            }
    }
}

// MARK: -

public struct SimpleSceneView: View {
    @Environment(\.metalDevice)
    var device

    @State
    var scene = SimpleScene.demo()

#if os(macOS)
    @State
    var isInspectorPresented = true
#else
    @State
    var isInspectorPresented = false
#endif

//    @State
//    var exportImage: Image?
//
//    @State
//    var label: String?

    public var body: some View {
        CoreSimpleSceneView(scene: $scene)
#if os(macOS)
        .showFrameEditor()
#endif
        .overlay(alignment: .bottomTrailing, content: mapView)
        .inspector(isPresented: $isInspectorPresented, content: inspector)
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

/*
 .toolbar {
 ToolbarItem(placement: .secondaryAction) {
 ValueView(value: false) { isPresentedBinding in
 Button(title: "Snapshot", systemImage: "camera") {
 Task {
 guard let device else {
 fatalError()
 }
 exportImage = Image(cgImage: try await renderPass!.snapshot(device: device))
 }
 }
 .fileExporter(isPresented: isPresentedBinding, item: exportImage, contentTypes: [.png, .jpeg]) { _ in
 exportImage = nil
 }
 .fileExporterFilenameLabel("Snapshot")
 }
 }
 }
 */
