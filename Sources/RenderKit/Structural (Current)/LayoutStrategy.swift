import Everything
import Foundation

public extension StructureDefinition {
    func layout<S>(strategy: S.Type) -> StructureLayout where S: LayoutStrategy {
        S.layout(for: self)
    }
}

public extension StructureDefinition {
    var metalLayout: StructureLayout {
        layout(strategy: CLayoutStrategy.self)
    }
}

public protocol LayoutStrategy {
    // TODO: Use AnyStructureDefinition
    static func layout(for structure: StructureDefinition) -> StructureLayout
}

public struct CLayoutStrategy: LayoutStrategy {
    // TODO: Use AnyStructureDefinition
    public static func layout(for structure: StructureDefinition) -> StructureLayout {
        guard let alignment = structure.attributes.max(by: { $0.kind.alignment < $1.kind.alignment })?.kind.alignment else {
            fatalError("No alighment found")
        }
        let offsets: [Int] = structure.attributes.reduce(into: [0]) { offsets, attribute in
            let size = attribute.kind.size
            let alignment = attribute.kind.alignment
            let offset = align(offset: offsets.last! + size, alignment: alignment)
            offsets += [offset]
        }
        .dropLast()

        let attributes: [AttributeLayout] = zip(structure.attributes, offsets).map { attribute, offset in
            AttributeLayout(name: attribute.name, kind: attribute.kind, offset: offset)
        }

        let size = offsets.last! + structure.attributes.last!.kind.size
        let stride = align(offset: size, alignment: alignment)

        return StructureLayout(attributes: attributes, alignment: alignment, stride: stride)
    }
}
