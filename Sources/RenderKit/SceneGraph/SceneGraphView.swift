import Everything
import Foundation
import simd
import SwiftUI

 public struct SceneGraphView: View {
    let renderer: DrawableRenderer

    public init(device: MTLDevice) {
        renderer = DrawableRenderer()
        let scene = try! Scene.demoSceneGraph(device: renderer.device)
        let subrenderer = try! SceneRenderer(device: renderer.device, sceneGraph: scene)
        renderer.add(subrenderer: subrenderer)
    }

    public var body: some View {
        try! RenderView(renderer: renderer) { view in
            view.depthStencilPixelFormat = .depth32Float
            view.depthStencilAttachmentTextureUsage = .renderTarget
            view.clearDepth = 1.0
        }
    }
 }
