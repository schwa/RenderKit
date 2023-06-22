import Foundation

// TODO: Highly experimental

public struct AnyMemoryLayout {
    public let size: Int
}

public extension MemoryLayout {
    static var eraseToAnyMemoryLayout: AnyMemoryLayout {
        AnyMemoryLayout(size: size)
    }
}

public protocol AttributeKey: Hashable {
}

public protocol AttributeKind {
    var memoryLayout: AnyMemoryLayout { get }
}

public struct AttributeDefinition<Key, Kind> where Key: AttributeKey {
    public let key: Key
    public let kind: Kind

    public init(key: Key, kind: Kind) {
        self.key = key
        self.kind = kind
    }
}

public struct CompoundDefinition<Key, Kind> where Key: AttributeKey {
    public let attributes: [AttributeDefinition<Key, Kind>]

    public init(attributes: [AttributeDefinition<Key, Kind>]) {
        self.attributes = attributes
    }
}

public struct AttributeLayout2 {
    public let buffer: Int
    public let start: Int
    public let end: Int
}

public struct CompoundLayout<Key> where Key: AttributeKey {
    public let layouts: [Key: AttributeLayout2]
    public let stride: Int

    public init<Kind>(definition: CompoundDefinition<Key, Kind>) where Kind: AttributeKind {
        var layouts: [Key: AttributeLayout2] = [:]
        var start = 0
        for attribute in definition.attributes {
            let end = start + attribute.kind.memoryLayout.size
            layouts[attribute.key] = AttributeLayout2(buffer: 0, start: start, end: end)
            start = end
        }
        self.layouts = layouts
        stride = start
    }

    public func layout(for key: Key) -> AttributeLayout2 {
        layouts[key]!
    }
}

public struct ValueAccessor<Key, Buffer> where Key: AttributeKey, Buffer: RangeReplaceableCollection, Buffer.Element == UInt8 {
    public private(set) var buffers: [Buffer]
    public let layout: CompoundLayout<Key>

    public init(buffers: [Buffer], layout: CompoundLayout<Key>) {
        self.buffers = buffers
        self.layout = layout
    }

    public mutating func set<T>(key: Key, value: T) {
        var value = value
        withUnsafeBytes(of: &value) { valueBuffer in
            let attributeLayout = layout.layout(for: key)
            assert(valueBuffer.count == attributeLayout.end - attributeLayout.start)
            let buffer = buffers[attributeLayout.buffer]
            let start = buffer.index(buffer.startIndex, offsetBy: attributeLayout.start)
            let end = buffer.index(buffer.startIndex, offsetBy: attributeLayout.end)
            buffers[attributeLayout.buffer].replaceSubrange(start ..< end, with: valueBuffer)
        }
    }
}
