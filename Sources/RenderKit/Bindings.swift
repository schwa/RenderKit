import Everything
import Foundation

// NOTE: -> ResourceBinding
public struct ShaderBinding: Hashable, Codable {
    public enum Kind: String, Codable {
        case buffer
        case texture
        case sampler
        case constant
        case argumentBuffer = "argument" // NOTE: Are these just buffers?
    }

    public var kind: Kind
    private var index: Int
    var alias: String?

    public init(kind: ShaderBinding.Kind, index: Int) {
        self.kind = kind
        self.index = index
    }

    public init<T>(kind: ShaderBinding.Kind, index: T) where T: RawRepresentable, T.RawValue == Int {
        self.kind = kind
        self.index = index.rawValue
    }

    // swiftlint:disable:next force_try
    static let pattern = try! NSRegularExpression(pattern: #"^(?<kind>[A-Za-z]+)#(?<index>[0-9]+)$"#)

    @UncheckedAtomic
    static var aliases: [String: ShaderBinding] = [:]

    public init(string: String) throws {
        if let alias = ShaderBinding.aliases[string] {
            self = alias
            self.alias = string
        }
        else {
            guard let match = ShaderBinding.pattern.firstMatch(in: string, options: []) else {
                throw UndefinedError()
            }
            guard let kind = Kind(rawValue: match.group(named: "kind", in: string)!) else {
                throw UndefinedError()
            }
            guard let indexString = match.group(named: "index", in: string) else {
                throw UndefinedError()
            }
            guard let index = Int(indexString) else {
                throw UndefinedError()
            }
            self = .init(kind: kind, index: index)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = try .init(string: string)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(kind.rawValue)#\(index)")
    }

    var bufferIndex: Int {
        get throws {
            guard case .buffer = kind else { throw UndefinedError("Binding \(self) incorrect type.") }
            return index
        }
    }

    var textureIndex: Int {
        get throws {
            guard case .texture = kind else { throw UndefinedError("Binding \(self) incorrect type.") }
            return index
        }
    }

    var samplerIndex: Int {
        get throws {
            guard case .sampler = kind else { throw UndefinedError() }
            return index
        }
    }

    var constantIndex: Int {
        get throws {
            guard case .constant = kind else { throw UndefinedError() }
            return index
        }
    }

    var argumentBufferIndex: Int {
        get throws {
            guard case .argumentBuffer = kind else { throw UndefinedError() }
            return index
        }
    }
}

extension ShaderBinding: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        // swiftlint:disable:next force_try
        self = try! .init(string: value)
    }
}

extension ShaderBinding: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(kind.rawValue)#\(index)"
    }
}

public protocol ShaderIndex: RawRepresentable {
    var kind: ShaderBinding.Kind { get }
}
