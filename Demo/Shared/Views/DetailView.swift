import CoreGraphicsGeometrySupport
import Everything
import Foundation
import RenderKit
import RenderKitSupport
import Shaders
import SIMDSupport
import SwiftUI
import RenderKitSceneGraph

struct DetailView: View {
    @EnvironmentObject
    var model: RenderModel

    var body: some View {
        SceneGraphView().environmentObject(model.sceneGraph)
//            CameraControllerView()
//                .environmentObject(model.scene.cameraController)
    }
}

struct SceneGraphView: View {
    @EnvironmentObject
    var sceneGraph: SceneGraph

    @State
    var selection = Set<Node.ID>()

    var body: some View {
        #if os(macOS)
            VSplitView {
                List([sceneGraph.scene], children: \.children, selection: $selection) { node in
                    Label(node)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                nodeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .controlSize(.small)
        #else
            EmptyView()
        #endif
    }

    func nodeView() -> some View {
        ScrollView {
            switch selection.count {
            case 0:
                Text("No Selection")
            case 1:
                selection.first.map { sceneGraph.scene.node(for: $0).map { NodeDetailView(node: $0) } }
            default:
                Text("Multiple selection")
            }
        }
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ base: some CustomInterfaceRepresentable) {
        let representation = base.interfaceRepresentation
        self.init(title: { Text(representation.shortDescription ?? representation.title!) }, icon: { representation.icon! })
    }
}

extension SceneNode {
    func node(for id: Node.ID) -> Node? {
        var node: Node?
        walk({ if $0.id == id { node = $0 } })
        return node
    }
}

struct NodeDetailView: View {
    let node: Node

    var body: some View {
        Fields {
            Text("Name")
            Text(verbatim: node.name ?? "untitled")
            Text("ID")
            Text(verbatim: "\(node.id.description)")
            Text("Transform")
            VStack {
                TransformEditorView(node.transform)
            }
        }
    }
}

struct Fields<Content>: View where Content: View {
    @ViewBuilder
    let content: () -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.fixed(80), alignment: .trailing), GridItem(alignment: .leading)]) {
            content().border(Color.red)
        }
        .border(Color.red)
    }
}

extension CameraController {
    var heading: SIMDSupport.Angle<Float> {
        get {
            let degrees = Angle(from: .zero, to: target.xz).degrees
            return Angle(degrees: degrees)
        }
        set {
            let length = target.length
            target = SIMD3<Float>(xz: SIMD2<Float>(length: length, angle: newValue))
        }
    }
}

