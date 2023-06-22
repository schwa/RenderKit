import Everything
import Foundation
import simd

// https://github.com/ephtracy/voxel-model/blob/master/MagicaVoxel-file-format-vox.txt
// https://github.com/ephtracy/voxel-model/blob/master/MagicaVoxel-file-format-vox-extension.txt

public struct MagicaVoxelModel: Sendable {
    public let size: SIMD3<UInt32>
    public let voxels: [(SIMD3<UInt8>, UInt8)]
    public let colors: [SIMD4<UInt8>]
}

extension MagicaVoxelModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(type(of: self))(size: \(size), voxels: \(voxels), colors: \(Array(colors.enumerated()))"
    }
}

public extension MagicaVoxelModel {
    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        let mainChunk = try data.withUnsafeBytes { buffer -> VoxelChunk in
            let buffer = Array(buffer.bindMemory(to: UInt8.self))
            var scanner = CollectionScanner(elements: buffer)

            guard let header = scanner.scan(count: 4).map({ String(bytes: $0, encoding: .utf8)! }), header == "VOX " else {
                throw UndefinedError()
            }
            guard let version = scanner.scan(type: UInt32.self), version == 150 else {
                throw UndefinedError()
            }
            guard let mainChunk = scanner.scan(type: VoxelChunk.self) else {
                throw UndefinedError()
            }
            return mainChunk
        }
        self = MagicaVoxelModel.instantiate(mainChunk: mainChunk)
    }

    init(named name: String, bundle: Bundle = Bundle.main) throws {
        let url = bundle.url(forResource: name, withExtension: "vox")!
        self = try .init(contentsOf: url)
    }
}

public extension MagicaVoxelModel {
    static func instantiate(mainChunk: VoxelChunk) -> MagicaVoxelModel {
        assert(mainChunk.type == .main)

        var size: SIMD3<UInt32>?
        var voxels: [(SIMD3<UInt8>, UInt8)]?
        var colors: [SIMD4<UInt8>]?

        for child in mainChunk.children {
            switch child.type {
            case .modelSize:
                var scanner = CollectionScanner(elements: child.content)
                size = scanner.scan(type: SIMD3<UInt32>.self)
                if size == nil {
                    fatalError("Could not scan size")
                }
            case .voxels:
                var scanner = CollectionScanner(elements: child.content)
                guard let count = scanner.scan(type: UInt32.self) else {
                    fatalError("Parsing error")
                }
                voxels = (0 ..< count).map { _ in
                    guard let position = scanner.scan(type: SIMD3<UInt8>.self) else {
                        fatalError("Parsing error")
                    }
                    guard let index = scanner.scan(type: UInt8.self) else {
                        fatalError("Parsing error")
                    }
                    return (position, UInt8(index))
                }
            case .colorPalette:
                var scanner = CollectionScanner(elements: child.content)
                let offsetColors: [SIMD4<UInt8>] = (0 ..< 256).map { _ in
                    guard let color = scanner.scan(type: SIMD4<UInt8>.self) else {
                        fatalError("Parsing error")
                    }
                    return color
                }
                colors = [
                    [255, 0, 0, 255],
                ] + offsetColors[0 ... 254]

            case .material, .renderObject, .renderCamera, .layer, .paletteNote, .indexMap, .transform, .group, .shape:
                continue
            default:
                warning("Unknown: \(child.type)")
                continue
            }
        }
        return MagicaVoxelModel(size: size!, voxels: voxels!, colors: colors!)
    }
}

// MARK: -

public struct VoxelChunk {
    public let type: ChunkType
    public let content: [UInt8]
    public let children: [VoxelChunk]
}

// MARK: -

public struct ChunkType: RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let main: ChunkType = "MAIN"
    public static let modelSize: ChunkType = "SIZE"
    public static let voxels: ChunkType = "XYZI"
    public static let colorPalette: ChunkType = "RGBA"

    public static let material: ChunkType = "MATL"
    public static let renderObject: ChunkType = "rOBJ"
    public static let renderCamera: ChunkType = "rCAM"
    public static let layer: ChunkType = "LAYR"
    public static let paletteNote: ChunkType = "NOTE"
    public static let indexMap: ChunkType = "IMAP"
    public static let transform: ChunkType = "nTRN"
    public static let group: ChunkType = "nGRP"
    public static let shape: ChunkType = "nSHP"
}

extension ChunkType: Equatable {
}

extension ChunkType: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

// MARK: -

public extension VoxelChunk {
    func dump(depth: Int = 0) {
        let indent = String(repeatElement(" ", count: depth * 2))
        print("\(indent)\(type)")
        for child in children {
            child.dump(depth: depth + 1)
        }
    }
}

// MARK: -

public extension CollectionScanner where Element == UInt8 {
    mutating func scan(type: VoxelChunk.Type) -> VoxelChunk? {
        let saved = current
        guard let type = scan(count: 4).map({ String(bytes: $0, encoding: .utf8)! }) else {
            current = saved
            return nil
        }
        guard let contentSize = scan(type: UInt32.self) else {
            current = saved
            return nil
        }
        assert(contentSize >= 0)
        assert(contentSize < elements.count)
        guard let childrenSize = scan(type: UInt32.self) else {
            current = saved
            return nil
        }
        assert(childrenSize >= 0)
        assert(childrenSize < elements.count)
        guard let content = scan(count: Int(contentSize)) else {
            current = saved
            return nil
        }
        var children: [VoxelChunk] = []
        if childrenSize > 0 {
            guard let childrenBuffer = scan(count: Int(childrenSize)) else {
                current = saved
                return nil
            }
            var subscanner = CollectionScanner<[UInt8]>(elements: Array(childrenBuffer))
            while subscanner.atEnd == false {
                guard let child = subscanner.scan(type: VoxelChunk.self) else {
                    fatalError("Cannot scan voxel chunk")
                }
                children.append(child)
            }
        }
        return VoxelChunk(type: ChunkType(rawValue: type), content: Array(content), children: children)
    }
}
