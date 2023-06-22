import Everything
import Metal

// swiftlint:disable file_length

public enum ShaderStageKind: String, Decodable {
    case vertex = "vertex_shader"
    case fragment = "fragment_shader"
    case compute = "compute_shader"
    case tile = "tile_shader"
}

// TODO: use MetalValue.Meta and the Meta enum macro
public enum MetalDataType: String, Codable {
    // Note: add more types
    case int
    case float2
    case float3
}

public enum MetalValue: Codable {
    // Note: add more types
    case int(Int)
    case float2(SIMD2<Float>)
    case float3(SIMD3<Float>)

    enum CodingKeys: CodingKey {
        case type
        case value
    }

    var dataType: MetalDataType {
        switch self {
        case .int:
            return .int
        case .float2:
            return .float2
        case .float3:
            return .float3
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MetalDataType.self, forKey: .type)
        switch type {
        case .int:
            self = .int(try container.decode(Int.self, forKey: .value))
        case .float2:
            self = .float2(try container.decode(SIMD2<Float>.self, forKey: .value))
        case .float3:
            self = .float3(try container.decode(SIMD3<Float>.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dataType, forKey: .type)
        switch self {
        case .int(let value):
            try container.encode(value, forKey: .value)
        case .float2(let value):
            try container.encode(value, forKey: .value)
        case .float3(let value):
            try container.encode(value, forKey: .value)
        }
    }
}

// MARK: -

public struct Parameter: Codable, Identifiable {
    public enum Value: Codable {
        case variable(key: RenderEnvironment.Key)
        case constant(value: MetalValue)

        enum CodingKeys: CodingKey {
            case type
            case value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "key":
                self = .variable(key: try container.decode(RenderEnvironment.Key.self, forKey: .value))
            case "constant":
                self = .constant(value: try container.decode(MetalValue.self, forKey: .value))
            default:
                fatalError("Unkown type \(type)")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .variable(let value):
                try container.encode("key", forKey: .type)
                try container.encode(value, forKey: .value)
            case .constant(let value):
                try container.encode("constant", forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }
    }

    public let id = UUID().uuidString
    public let name: String?
    public let binding: ShaderBinding
    public let usage: MTLResourceUsage?
    public let value: Value

    public init(name: String? = nil, binding: ShaderBinding, usage: MTLResourceUsage? = [], value: Parameter.Value) {
        self.name = name
        self.binding = binding
        self.usage = usage
        self.value = value
    }

    enum CodingKeys: CodingKey {
        case name
        case binding
        case usage
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decodeIfPresent(String.self, forKey: .name)
        binding = try container.decode(ShaderBinding.self, forKey: .binding)
        usage = try container.decodeIfPresent(MTLResourceUsage.self, forKey: .usage)
        value = try container.decode(Value.self, forKey: .value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(binding, forKey: .binding)
        try container.encodeIfPresent(usage, forKey: .usage)
        try container.encode(value, forKey: .value)
    }
}

public struct FunctionConstant: Codable, Identifiable {
    public let id = UUID().uuidString
    public let name: String?
    public let binding: ShaderBinding
    public let value: MetalValue

    public init(name: String?, binding: ShaderBinding, value: MetalValue) {
        self.name = name
        self.binding = binding
        self.value = value
    }

    enum CodingKeys: CodingKey {
        case name
        case binding
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decodeIfPresent(String.self, forKey: .name)
        binding = try container.decode(ShaderBinding.self, forKey: .binding)
        value = try container.decode(MetalValue.self, forKey: .value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(binding, forKey: .binding)
        try container.encode(value, forKey: .value)
    }
}

public struct PassSelector: Hashable, Codable {
    let rawValue: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: -

extension PassSelector: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

extension PassSelector: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

// MARK: -

public struct RenderPassOptions: Codable, Hashable {
    enum CodingKeys: String, CodingKey {
        case frontFacing = "front_facing"
        case cullMode = "cull_mode"
        case fillMode = "fill_mode"
        case depthStencil = "depth_stencil"
        case colorAttachments = "color_attachments"
        case depthAttachment = "depth_attachment"
    }

    public var frontFacing: Winding
    public var cullMode: CullMode
    public var fillMode: FillMode
    public var depthStencil: DepthStencil
    public var colorAttachments: [RenderPassColorAttachmentDescriptor]?
    public var depthAttachment: RenderPassDepthAttachmentDescriptor?

    public init(frontFacing: Winding = .clockwise, cullMode: CullMode = .front, fillMode: FillMode = .fill, depthStencil: DepthStencil = DepthStencil(), colorAttachments: [RenderPassColorAttachmentDescriptor]? = nil, depthAttachment: RenderPassDepthAttachmentDescriptor? = nil) {
        self.frontFacing = frontFacing
        self.cullMode = cullMode
        self.fillMode = fillMode
        self.depthStencil = depthStencil
        self.colorAttachments = colorAttachments
        self.depthAttachment = depthAttachment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frontFacing = try container.decodeIfPresent(Winding.self, forKey: .frontFacing) ?? .clockwise
        cullMode = try container.decodeIfPresent(CullMode.self, forKey: .cullMode) ?? .front
        fillMode = try container.decodeIfPresent(FillMode.self, forKey: .fillMode) ?? .fill
        depthStencil = try container.decodeIfPresent(DepthStencil.self, forKey: .depthStencil) ?? DepthStencil()
        colorAttachments = try container.decodeIfPresent([RenderPassColorAttachmentDescriptor].self, forKey: .colorAttachments)
        depthAttachment = try container.decodeIfPresent(RenderPassDepthAttachmentDescriptor.self, forKey: .depthAttachment)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frontFacing, forKey: .frontFacing)
        try container.encode(cullMode, forKey: .cullMode)
        try container.encode(fillMode, forKey: .fillMode)
        try container.encode(depthStencil, forKey: .depthStencil)
        try container.encodeIfPresent(colorAttachments, forKey: .colorAttachments)
        try container.encodeIfPresent(depthAttachment, forKey: .depthAttachment)
    }
}

extension RenderPassOptions {
    public static let `default` = RenderPassOptions(
        frontFacing: .clockwise,
        cullMode: .front,
        fillMode: .fill,
        depthStencil: .init(compare: .lessEqual, depthWriteEnabled: true),
        colorAttachments: [
            .init(clearColor: [0, 0, 0, 1], loadAction: .load, storeAction: .store, texture: "$DRAWABLE_TEXTURE"),
        ],
        depthAttachment: RenderPassDepthAttachmentDescriptor(loadAction: .load, storeAction: .store, texture: "$DEPTH_TEXTURE")
    )

    public func modifiedForFirstPass() -> RenderPassOptions {
        var copy = self
        copy.colorAttachments = colorAttachments.map { colorAttachments in
            colorAttachments.map { colorAttachment in
                var colorAttachment = colorAttachment
                colorAttachment.loadAction = .clear
                return colorAttachment
            }
        }
        copy.depthAttachment = depthAttachment.map { depthAttachment in
            var depthAttachment = depthAttachment
            depthAttachment.loadAction = .clear
            return depthAttachment
        }
        return copy
    }

    public func modifiedForLastPass() -> RenderPassOptions {
        var copy = self
        copy.colorAttachments = colorAttachments.map { colorAttachments in
            colorAttachments.map { colorAttachment in
                var colorAttachment = colorAttachment
                colorAttachment.storeAction = .store
                return colorAttachment
            }
        }
        copy.depthAttachment = depthAttachment.map { depthAttachment in
            var depthAttachment = depthAttachment
            depthAttachment.storeAction = .dontCare
            return depthAttachment
        }
        return copy
    }
}

// MARK: -

public enum Winding: String, Codable, Hashable {
    case clockwise
    case counterClockwise = "counter_clockwise"
}

extension MTLWinding {
    init(_ value: Winding) {
        switch value {
        case .clockwise:
            self = .clockwise
        case .counterClockwise:
            self = .counterClockwise
        }
    }
}

// MARK: -

public enum CullMode: String, Codable, Hashable {
    case front
    case back
    // swiftlint:disable:next discouraged_none_name
    case none
}

extension MTLCullMode {
    init(_ value: CullMode) {
        switch value {
        case .front:
            self = .front
        case .back:
            self = .back
        case .none:
            self = .none
        }
    }
}

// MARK: -

public enum FillMode: String, Codable, Hashable {
    case fill
    case lines
}

extension MTLTriangleFillMode {
    init(_ value: FillMode) {
        switch value {
        case .fill:
            self = .fill
        case .lines:
            self = .lines
        }
    }
}

public enum DepthCompare: String, Codable, Hashable {
    case never = "false"
    case less = "<"
    case equal = "=="
    case lessEqual = "<="
    case greater = ">"
    case notEqual = "!="
    case greaterEqual = ">="
    case always = "true"
}

extension MTLCompareFunction {
    init(_ value: DepthCompare) {
        switch value {
        case .never:
            self = .never
        case .less:
            self = .less
        case .equal:
            self = .equal
        case .lessEqual:
            self = .lessEqual
        case .greater:
            self = .greater
        case .notEqual:
            self = .notEqual
        case .greaterEqual:
            self = .greaterEqual
        case .always:
            self = .always
        }
    }
}

public struct DepthStencil: Codable, Hashable {
    public var compare: DepthCompare
    public var depthWriteEnabled: Bool

    public init(compare: DepthCompare = .always, depthWriteEnabled: Bool = false) {
        self.compare = compare
        self.depthWriteEnabled = depthWriteEnabled
    }

    enum CodingKeys: String, CodingKey {
        case compare
        case depthWriteEnabled = "depth_write_enabled"
    }
}

extension MTLDepthStencilDescriptor {
    convenience init(_ value: DepthStencil) {
        self.init()
        depthCompareFunction = .init(value.compare)
        isDepthWriteEnabled = value.depthWriteEnabled
        // NOTE: Missing stencil info
        // frontFaceStencil = ...
        // backFaceStencil = ...
    }
}

// MARK: -

public struct RenderPassColorAttachmentDescriptor: Codable, Hashable {
    public var clearColor: SIMD4<Float>?
    public var loadAction: LoadAction
    public var storeAction: StoreAction
    public var texture: RenderEnvironment.Key?

    public init(clearColor: SIMD4<Float>? = nil, loadAction: LoadAction = .clear, storeAction: StoreAction = .store, texture: RenderEnvironment.Key? = nil) {
        self.clearColor = clearColor
        self.loadAction = loadAction
        self.storeAction = storeAction
        self.texture = texture
    }

    enum CodingKeys: String, CodingKey {
        case clearColor = "clear_color"
        case loadAction = "load_action"
        case storeAction = "store_action"
        case texture
    }
}

extension MTLRenderPassColorAttachmentDescriptor {
    convenience init(_ value: RenderPassColorAttachmentDescriptor, environment: RenderEnvironment) {
        self.init()
        if let clearColor = value.clearColor {
            let clearColor = SIMD4<Double>(clearColor)
            self.clearColor = MTLClearColor(red: clearColor.r, green: clearColor.g, blue: clearColor.b, alpha: clearColor.a)
        }
        loadAction = MTLLoadAction(value.loadAction)
        storeAction = MTLStoreAction(value.storeAction)
        if let key = value.texture, let value = environment[key] {
            if case .texture(let texture) = value {
                self.texture = texture
            }
        }
    }
}

// MARK: -

public struct RenderPassDepthAttachmentDescriptor: Codable, Hashable {
    var loadAction: LoadAction
    var storeAction: StoreAction
    var texture: RenderEnvironment.Key?

    public init(loadAction: LoadAction = .clear, storeAction: StoreAction = .dontCare, texture: RenderEnvironment.Key? = nil) {
        self.loadAction = loadAction
        self.storeAction = storeAction
        self.texture = texture
    }

    enum CodingKeys: String, CodingKey {
        case loadAction = "load_action"
        case storeAction = "store_action"
        case texture
    }
}

extension MTLRenderPassDepthAttachmentDescriptor {
    convenience init(_ value: RenderPassDepthAttachmentDescriptor, environment: RenderEnvironment) {
        self.init()
        loadAction = MTLLoadAction(value.loadAction)
        storeAction = MTLStoreAction(value.storeAction)
        if let key = value.texture, let value = environment[key] {
            if case .texture(let texture) = value {
                self.texture = texture
            }
        }
    }
}

public enum LoadAction: String, Codable {
    case dontCare = "dont_care"
    case load
    case clear
}

extension MTLLoadAction {
    init(_ value: LoadAction) {
        switch value {
        case .dontCare:
            self = .dontCare
        case .load:
            self = .load
        case .clear:
            self = .clear
        }
    }
}

public enum StoreAction: String, Codable {
    case dontCare = "dont_care"
    case store
    case multisampleResolve = "multisample_resolve"
    case customSampleDepthStore = "custom_sample_depth_store"
}

extension MTLStoreAction {
    init(_ value: StoreAction) {
        switch value {
        case .dontCare:
            self = .dontCare
        case .store:
            self = .store
        case .multisampleResolve:
            self = .multisampleResolve
        case .customSampleDepthStore:
            self = .customSampleDepthStore
        }
    }
}

public extension Parameter {
    init<T>(index: T, variable: String, usage: MTLResourceUsage = .read) where T: ShaderIndex, T.RawValue == Int {
        self.init(binding: ShaderBinding(kind: index.kind, index: index), value: .variable(key: RenderEnvironment.Key(variable)))
    }
}

public extension Parameter {
    init<T>(index: T, constant: SIMD3<Float>, usage: MTLResourceUsage = .read) where T: ShaderIndex, T.RawValue == Int {
        self.init(binding: ShaderBinding(kind: index.kind, index: index), value: .constant(value: .float3(constant)))
    }
}

public extension FunctionConstant {
    init<T>(index: T, value: MetalValue) where T: ShaderIndex, T.RawValue == Int {
        self.init(name: nil, binding: ShaderBinding(kind: index.kind, index: index), value: value)
    }
}

extension MetalValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension MetalValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        switch elements.count {
        case 2:
            self = .float2(SIMD2<Float>(elements))
        case 3:
            self = .float3(SIMD3<Float>(elements))
        default:
            unimplemented()
        }
    }
}
