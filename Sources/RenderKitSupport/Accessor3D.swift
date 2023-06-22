import Foundation

public struct Adapter3D<Base> where Base: RandomAccessCollection {
    public typealias Element = Base.Element
    public typealias Point = SIMD3<Int>
    public typealias Size = SIMD3<Int>

    public var base: Base
    public let size: Size

    public init(base: Base, size: Size) {
        assert(base.count == size.x * size.y * size.z)
        self.base = base
        self.size = size
    }
}

public extension Adapter3D {
    struct Index: Equatable, Comparable {
        public typealias BaseIndex = Base.Index

        let base: BaseIndex
        let size: Size

        public static func == (lhs: Self, rhs: Self) -> Bool {
            assert(lhs.size == rhs.size)
            return lhs.base == rhs.base
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            assert(lhs.size == rhs.size)
            return lhs.base < rhs.base
        }
    }

    var startIndex: Index {
        Index(base: base.startIndex, size: size)
    }

    var endIndex: Index {
        Index(base: base.endIndex, size: size)
    }

    subscript(index: Index) -> Element {
        assert(index.size == size)
        assert(index.base < base.endIndex)
        return base[index.base]
    }
}

// MARK: -

extension Adapter3D: MutableCollection where Base: MutableCollection {
    public subscript(index: Index) -> Element {
        get {
            assert(index.size == size)
            assert(index.base < base.endIndex)
            return base[index.base]
        }
        set {
            assert(index.size == size)
            assert(index.base < base.endIndex)
            base[index.base] = newValue
        }
    }
}

// MARK: -

extension Adapter3D.Index: Hashable where Adapter3D.Index.BaseIndex: Hashable {
}

// MARK: -

extension Adapter3D.Index: Strideable where BaseIndex: Strideable {
    public typealias Stride = BaseIndex.Stride

    public func distance(to other: Self) -> Stride {
        base.distance(to: other.base)
    }

    public func advanced(by n: Stride) -> Self {
        Self(base: base.advanced(by: n), size: size)
    }
}

// MARK: -

extension Adapter3D: Sequence {
    public func makeIterator() -> Iterator {
        Iterator(array: self)
    }

    public struct Iterator: IteratorProtocol {
        let array: Adapter3D
        let endIndex: Adapter3D.Index
        var currentIndex: Adapter3D.Index

        public init(array: Adapter3D) {
            self.array = array
            endIndex = array.endIndex
            currentIndex = array.startIndex
        }

        public mutating func next() -> Element? {
            guard currentIndex < endIndex else {
                return nil
            }
            let result = array[currentIndex]
            currentIndex = array.index(after: currentIndex)
            return result
        }
    }
}

// MARK: -

extension Adapter3D: Collection {
    public func index(after i: Index) -> Index {
        Index(base: base.index(after: i.base), size: i.size)
    }
}

// MARK: -

extension Adapter3D: BidirectionalCollection {
    public func index(before i: Index) -> Index {
        Index(base: base.index(before: i.base), size: i.size)
    }
}

// MARK: -

extension Adapter3D: RandomAccessCollection {
}

extension Adapter3D {
    public subscript(index: SIMD3<Int>) -> Element {
        let offset = index.x + index.y * size.x + index.z * (size.x * size.y)
        let baseIndex = base.index(base.startIndex, offsetBy: offset)
        let index = Index(base: baseIndex, size: size)
        return self[index]
    }
}

extension Adapter3D where Base: MutableCollection {
    public subscript(index: SIMD3<Int>) -> Element {
        get {
            let offset = index.x + index.y * size.x + index.z * (size.x * size.y)
            let baseIndex = base.index(base.startIndex, offsetBy: offset)
            let index = Index(base: baseIndex, size: size)
            return self[index]
        }
        set {
            let offset = index.x + index.y * size.x + index.z * (size.x * size.y)
            let baseIndex = base.index(base.startIndex, offsetBy: offset)
            let index = Index(base: baseIndex, size: size)
            self[index] = newValue
        }
    }
}
