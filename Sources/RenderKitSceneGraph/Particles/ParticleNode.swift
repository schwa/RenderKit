import RenderKitSupport
import SwiftUI

public class ParticleNode: Node {
    override public var interfaceRepresentation: InterfaceRepresentation {
        .init(icon: Image(systemName: "sparkles"), title: String(describing: self), shortDescription: "Particle Node \"\(name ?? "Untitled")\"")
    }
}
