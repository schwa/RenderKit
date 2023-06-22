import Metal

public extension MTLRenderCommandEncoder {
    func setVertexBytes<Index: RawRepresentable>(_ bytes: UnsafeRawPointer, length: Int, index: Index) where Index.RawValue == Int {
        setVertexBytes(bytes, length: length, index: index.rawValue)
    }

    func setVertexValue<T>(_ value: inout T, index: Int) {
        setVertexBytes(&value, length: MemoryLayout<T>.size, index: index)
    }

    func setVertexValue<T, Index: RawRepresentable>(_ value: inout T, index: Index) where Index.RawValue == Int {
        setVertexBytes(&value, length: MemoryLayout<T>.size, index: index.rawValue)
    }

    func setFragmentBytes<Index: RawRepresentable>(_ bytes: UnsafeRawPointer, length: Int, index: Index) where Index.RawValue == Int {
        setFragmentBytes(bytes, length: length, index: index.rawValue)
    }

    func setFragmentValue<T, Index: RawRepresentable>(_ value: inout T, index: Index) where Index.RawValue == Int {
        setFragmentBytes(&value, length: MemoryLayout<T>.size, index: index.rawValue)
    }

    func setFragmentValue<T>(_ value: inout T, index: Int) {
        setFragmentBytes(&value, length: MemoryLayout<T>.size, index: index)
    }

    func setVertexBytes<Element>(_ vertices: [Element], index: Int) where Element: SIMD {
        let length = MemoryLayout<Element>.stride * vertices.count
        setVertexBytes(vertices, length: length, index: index)
    }

    func setVertexBytes<Element, Index>(_ vertices: [Element], index: Index) where Element: SIMD, Index: RawRepresentable, Index.RawValue == Int {
        let length = MemoryLayout<Element>.stride * vertices.count
        setVertexBytes(vertices, length: length, index: index)
    }

    func setFragmentTexture<Index>(_ texture: MTLTexture, index: Index) where Index: RawRepresentable, Index.RawValue == Int {
        setFragmentTexture(texture, index: index.rawValue)
    }
}
