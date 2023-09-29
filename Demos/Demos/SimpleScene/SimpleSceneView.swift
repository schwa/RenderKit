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

public struct SimpleSceneView: View {
    @Environment(\.metalDevice)
    var device

    @Binding
    var scene: SimpleScene

    @State
    var renderPass: SimpleSceneRenderPass?

#if os(macOS)
    @State
    var isInspectorPresented = true
#else
    @State
    var isInspectorPresented = false
#endif

    @State
    var exportImage: Image?

    @State
    var label: String?

    public init(scene: Binding<SimpleScene>) {
        self._scene = scene
    }

    public var body: some View {
        ZStack {
            if renderPass != nil {
                RendererView(renderPass: $renderPass)
                    .overlay(alignment: .bottomTrailing) {
                        SimpleSceneMapView(scene: $scene)
                            .border(Color.red)
                            .frame(width: 200, height: 200)
                            .padding()
                    }
                    .onAppear {
                        self.renderPass?.scene = scene
                    }
                    .onChange(of: scene.camera) {
                        self.renderPass?.scene = scene
                    }
#if os(macOS)
                .showFrameEditor()
#endif
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
                .inspector(isPresented: $isInspectorPresented) {
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
        }
        .onAppear {
            renderPass = SimpleSceneRenderPass(scene: scene)
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
