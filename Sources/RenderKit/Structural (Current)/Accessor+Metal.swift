import Metal

public extension MTLRenderCommandEncoder {
    func setVertexBytes<C>(_ collection: C, index: Int) where C: Collection, C.Element == UInt8 {
        let result = collection.withContiguousStorageIfAvailable { buffer -> Bool in
            setVertexBytes(buffer.baseAddress!, length: buffer.count, index: index)
            return true
        }
        guard result == true else {
            fatalError("Could not get contiguous storage.")
        }
    }

    func setFragmentBytes<C>(_ collection: C, index: Int) where C: Collection, C.Element == UInt8 {
        let result = collection.withContiguousStorageIfAvailable { buffer -> Bool in
            setFragmentBytes(buffer.baseAddress!, length: buffer.count, index: index)
            return true
        }
        guard result == true else {
            fatalError("Could not get contiguous storage.")
        }
    }
}
