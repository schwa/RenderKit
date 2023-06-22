import Everything
import Foundation

// TODO: Should work like a collection
public struct Accessor<Storage, Row> where Storage: RangeReplaceableCollection, Row: AccessorRow, Row.RowStorage == Storage.SubSequence {
    public let layout: StructureLayout
    public var storage: Storage

    public init(layout: StructureLayout, storage: Storage) {
        self.layout = layout
        self.storage = storage
    }

    public subscript(index: Int) -> Row {
        get {
            let start = storage.index(storage.startIndex, offsetBy: layout.stride * index)
            let end = storage.index(start, offsetBy: layout.size)
            let slice = storage[start ..< end]
            return Row(layout: layout, storage: slice)
        }
        set {
            let start = storage.index(storage.startIndex, offsetBy: layout.stride * index)
            let end = storage.index(start, offsetBy: layout.size)
            storage.replaceSubrange(start ..< end, with: newValue.storage)
        }
    }
}

// MARK: -

// TODO: Removed due to weird Swift protocol error.
//extension Accessor: Sequence, Collection, RangeReplaceableCollection {
//    public init() {
//        unimplemented()
//    }
//
//    public func index(after i: Int) -> Int {
//        i + 1
//    }
//
//    public var startIndex: Int {
//        0
//    }
//
//    public var endIndex: Int {
//        count
//    }
//
//    public var count: Int {
//        storage.count / layout.stride
//    }
//}

// MARK: -

// TODO: Should work a bit like a dictionary.
public protocol AccessorRow {
    associatedtype RowStorage where RowStorage: RangeReplaceableCollection, RowStorage.Element == UInt8
    var layout: StructureLayout { get }
    var storage: RowStorage { get set }
    init(layout: StructureLayout, storage: RowStorage)
}

public extension AccessorRow {
    subscript<T>(key: String) -> T {
        get {
            guard let layout = layout.attributeLayouts[key] else {
                fatalError("No attribute for key")
            }
            let start = storage.index(storage.startIndex, offsetBy: layout.kind.size)
            let end = storage.index(start, offsetBy: layout.kind.size)
            let slice = storage[start ..< end]
            var maybeValue = slice.withContiguousStorageIfAvailable { buffer in
                buffer.withMemoryRebound { (buffer: UnsafeBufferPointer<T>) in
                    buffer[0]
                }
            }
            if maybeValue == nil {
                let bytes = [UInt8](slice)
                maybeValue = bytes.withContiguousStorageIfAvailable { buffer in
                    buffer.withMemoryRebound { (buffer: UnsafeBufferPointer<T>) in
                        buffer[0]
                    }
                }
            }
            guard let value = maybeValue else {
                fatalError("No contiguous storage")
            }
            return value
        }
        set {
            guard let layout = layout.attributeLayouts[key] else {
                fatalError("No layout for \(key)")
            }
            assert(MemoryLayout<T>.size == layout.kind.size)
            let start = storage.index(storage.startIndex, offsetBy: layout.offset)
            let end = storage.index(start, offsetBy: layout.kind.size)
            var newValue = newValue
            withUnsafeBytes(of: &newValue) { buffer in
                storage.replaceSubrange(start ..< end, with: buffer)
            }
        }
    }
}

@dynamicMemberLookup
public struct DynamicRow<RowStorage>: AccessorRow where RowStorage: RangeReplaceableCollection, RowStorage.Element == UInt8 {
    public let layout: StructureLayout
    public var storage: RowStorage

    public init(layout: StructureLayout, storage: RowStorage) {
        self.layout = layout
        self.storage = storage
    }

    public subscript<T>(dynamicMember key: String) -> T {
        get {
            self[key]
        }
        set {
            self[key] = newValue
        }
    }
}

// MARK: -

public extension Accessor where Storage == [UInt8] {
    init(layout: StructureLayout, count: Int) {
        self = Accessor(layout: layout, storage: [UInt8](repeating: 0, count: layout.stride * count))
    }
}
