import SwiftUI

public struct InterfaceRepresentation {
    public init(icon: Image? = nil, title: String? = nil, subtitle: String? = nil, shortDescription: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.shortDescription = shortDescription
    }

    public var icon: Image?
    public var title: String?
    public var subtitle: String?
    public var shortDescription: String?
    // TODO: AX fields
}

public protocol CustomInterfaceRepresentable {
    var interfaceRepresentation: InterfaceRepresentation { get }
}
