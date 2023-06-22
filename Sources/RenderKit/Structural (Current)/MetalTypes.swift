import Foundation

public struct MetalType {
    public let name: String
    public let size: Int
    public let alignment: Int
    public let aliases: [String]

    init(name: String, size: Int, alignment: Int, aliases: [String] = []) {
        self.name = name
        self.size = size
        self.alignment = alignment
        self.aliases = aliases
    }
}

extension MetalType: Equatable {
    public static func == (lhs: MetalType, rhs: MetalType) -> Bool {
        lhs.id == rhs.id
    }
}

extension MetalType: Identifiable {
    public var id: String {
        name
    }
}

public extension MetalType {
    static var typesByName: [String: MetalType] = {
        var typesByName: [String: MetalType] = [:]
        MetalType.allCases.forEach { type in
            typesByName[type.name] = type
            for alias in type.aliases {
                typesByName[alias] = type
            }
        }
        return typesByName
    }()

    static func type(for name: String) -> MetalType? {
        typesByName[name]
    }

    init(name: String) {
        self = MetalType.type(for: name)!
    }
}

public extension MetalType {
    static let bool = MetalType(name: "bool", size: 1, alignment: 1)
    static let char = MetalType(name: "char", size: 1, alignment: 1, aliases: ["int8_t"])
    static let unsigned_char = MetalType(name: "unsigned char", size: 1, alignment: 1, aliases: ["uchar", "uint8_t"])
    static let short = MetalType(name: "short", size: 2, alignment: 2, aliases: ["int16_t"])
    static let unsigned_short = MetalType(name: "unsigned short", size: 2, alignment: 2, aliases: ["ushort", "unit16_t"])
    static let int = MetalType(name: "int", size: 4, alignment: 4, aliases: ["int32_t"])
    static let unsigned_int = MetalType(name: "unsigned int", size: 4, alignment: 4, aliases: ["uint", "uint32_t"])
    static let half = MetalType(name: "half", size: 2, alignment: 2)
    static let float = MetalType(name: "float", size: 4, alignment: 4)
    static let bool2 = MetalType(name: "bool2", size: 2, alignment: 2)
    static let bool3 = MetalType(name: "bool3", size: 4, alignment: 4)
    static let bool4 = MetalType(name: "bool4", size: 4, alignment: 4)
    static let char2 = MetalType(name: "char2", size: 2, alignment: 2)
    static let uchar2 = MetalType(name: "uchar2", size: 2, alignment: 2)
    static let char3 = MetalType(name: "char3", size: 4, alignment: 4)
    static let uchar3 = MetalType(name: "uchar3", size: 4, alignment: 4)
    static let char4 = MetalType(name: "char4", size: 4, alignment: 4)
    static let uchar4 = MetalType(name: "uchar4", size: 4, alignment: 4)
    static let short2 = MetalType(name: "short2", size: 4, alignment: 4)
    static let ushort2 = MetalType(name: "ushort2", size: 4, alignment: 4)
    static let short3 = MetalType(name: "short3", size: 8, alignment: 8)
    static let ushort3 = MetalType(name: "ushort3", size: 8, alignment: 8)
    static let short4 = MetalType(name: "short4", size: 8, alignment: 8)
    static let ushort4 = MetalType(name: "ushort4", size: 8, alignment: 8)
    static let int2 = MetalType(name: "int2", size: 8, alignment: 8)
    static let uint2 = MetalType(name: "uint2", size: 8, alignment: 8)
    static let int3 = MetalType(name: "int3", size: 16, alignment: 16)
    static let uint3 = MetalType(name: "uint3", size: 16, alignment: 16)
    static let int4 = MetalType(name: "int4", size: 16, alignment: 16)
    static let uint4 = MetalType(name: "uint4", size: 16, alignment: 16)
    static let half2 = MetalType(name: "half2", size: 4, alignment: 4)
    static let half3 = MetalType(name: "half3", size: 8, alignment: 8)
    static let half4 = MetalType(name: "half4", size: 8, alignment: 8)
    static let float2 = MetalType(name: "float2", size: 8, alignment: 8)
    static let float3 = MetalType(name: "float3", size: 16, alignment: 16)
    static let float4 = MetalType(name: "float4", size: 16, alignment: 16)
    static let packed_char2 = MetalType(name: "packed_char2", size: 2, alignment: 1)
    static let packed_uchar2 = MetalType(name: "packed_uchar2", size: 2, alignment: 1)
    static let packed_char3 = MetalType(name: "packed_char3", size: 3, alignment: 1)
    static let packed_uchar3 = MetalType(name: "packed_uchar3", size: 3, alignment: 1)
    static let packed_char4 = MetalType(name: "packed_char4", size: 4, alignment: 1)
    static let packed_uchar4 = MetalType(name: "packed_uchar4", size: 4, alignment: 1)
    static let packed_short2 = MetalType(name: "packed_short2", size: 4, alignment: 2)
    static let packed_ushort2 = MetalType(name: "packed_ushort2", size: 4, alignment: 2)
    static let packed_short3 = MetalType(name: "packed_short3", size: 6, alignment: 2)
    static let packed_ushort3 = MetalType(name: "packed_ushort3", size: 6, alignment: 2)
    static let packed_short4 = MetalType(name: "packed_short4", size: 8, alignment: 2)
    static let packed_ushort4 = MetalType(name: "packed_ushort4", size: 8, alignment: 2)
    static let packed_int2 = MetalType(name: "packed_int2", size: 8, alignment: 4)
    static let packed_uint2 = MetalType(name: "packed_uint2", size: 8, alignment: 4)
    static let packed_int3 = MetalType(name: "packed_int3", size: 12, alignment: 4)
    static let packed_uint3 = MetalType(name: "packed_uint3", size: 12, alignment: 4)
    static let packed_int4 = MetalType(name: "packed_int4", size: 16, alignment: 4)
    static let packed_uint4 = MetalType(name: "packed_uint4", size: 16, alignment: 4)
    static let packed_half2 = MetalType(name: "packed_half2", size: 4, alignment: 2)
    static let packed_half3 = MetalType(name: "packed_half3", size: 6, alignment: 2)
    static let packed_half4 = MetalType(name: "packed_half4", size: 8, alignment: 2)
    static let packed_float2 = MetalType(name: "packed_float2", size: 8, alignment: 4)
    static let packed_float3 = MetalType(name: "packed_float3", size: 12, alignment: 4)
    static let packed_float4 = MetalType(name: "packed_float4", size: 16, alignment: 4)
    static let half2x2 = MetalType(name: "half2x2", size: 8, alignment: 4)
    static let half2x3 = MetalType(name: "half2x3", size: 16, alignment: 8)
    static let half2x4 = MetalType(name: "half2x4", size: 16, alignment: 8)
    static let half3x2 = MetalType(name: "half3x2", size: 12, alignment: 4)
    static let half3x3 = MetalType(name: "half3x3", size: 24, alignment: 8)
    static let half3x4 = MetalType(name: "half3x4", size: 24, alignment: 8)
    static let half4x2 = MetalType(name: "half4x2", size: 16, alignment: 4)
    static let half4x3 = MetalType(name: "half4x3", size: 32, alignment: 8)
    static let half4x4 = MetalType(name: "half4x4", size: 32, alignment: 8)
    static let float2x2 = MetalType(name: "float2x2", size: 16, alignment: 8)
    static let float2x3 = MetalType(name: "float2x3", size: 32, alignment: 16)
    static let float2x4 = MetalType(name: "float2x4", size: 32, alignment: 16)
    static let float3x2 = MetalType(name: "float3x2", size: 24, alignment: 8)
    static let float3x3 = MetalType(name: "float3x3", size: 48, alignment: 16)
    static let float3x4 = MetalType(name: "float3x4", size: 48, alignment: 16)
    static let float4x2 = MetalType(name: "float4x2", size: 32, alignment: 8)
    static let float4x3 = MetalType(name: "float4x3", size: 64, alignment: 16)
    static let float4x4 = MetalType(name: "float4x4", size: 64, alignment: 16)
}

extension MetalType: CaseIterable {
    public static let allCases: [MetalType] = [
        MetalType.bool,
        MetalType.char,
        MetalType.unsigned_char,
        MetalType.short,
        MetalType.unsigned_short,
        MetalType.int,
        MetalType.unsigned_int,
        MetalType.half,
        MetalType.float,
        MetalType.bool2,
        MetalType.bool3,
        MetalType.bool4,
        MetalType.char2,
        MetalType.uchar2,
        MetalType.char3,
        MetalType.uchar3,
        MetalType.char4,
        MetalType.uchar4,
        MetalType.short2,
        MetalType.ushort2,
        MetalType.short3,
        MetalType.ushort3,
        MetalType.short4,
        MetalType.ushort4,
        MetalType.int2,
        MetalType.uint2,
        MetalType.int3,
        MetalType.uint3,
        MetalType.int4,
        MetalType.uint4,
        MetalType.half2,
        MetalType.half3,
        MetalType.half4,
        MetalType.float2,
        MetalType.float3,
        MetalType.float4,
        MetalType.packed_char2,
        MetalType.packed_uchar2,
        MetalType.packed_char3,
        MetalType.packed_uchar3,
        MetalType.packed_char4,
        MetalType.packed_uchar4,
        MetalType.packed_short2,
        MetalType.packed_ushort2,
        MetalType.packed_short3,
        MetalType.packed_ushort3,
        MetalType.packed_short4,
        MetalType.packed_ushort4,
        MetalType.packed_int2,
        MetalType.packed_uint2,
        MetalType.packed_int3,
        MetalType.packed_uint3,
        MetalType.packed_int4,
        MetalType.packed_uint4,
        MetalType.packed_half2,
        MetalType.packed_half3,
        MetalType.packed_half4,
        MetalType.packed_float2,
        MetalType.packed_float3,
        MetalType.packed_float4,
        MetalType.half2x2,
        MetalType.half2x3,
        MetalType.half2x4,
        MetalType.half3x2,
        MetalType.half3x3,
        MetalType.half3x4,
        MetalType.half4x2,
        MetalType.half4x3,
        MetalType.half4x4,
        MetalType.float2x2,
        MetalType.float2x3,
        MetalType.float2x4,
        MetalType.float3x2,
        MetalType.float3x3,
        MetalType.float3x4,
        MetalType.float4x2,
        MetalType.float4x3,
        MetalType.float4x4,
    ]
}

extension MetalType {
    static func ~= (lhs: MetalType, rhs: MetalType) -> Bool {
        lhs.name == rhs.name
    }
}

extension MetalType {
    var cName: String {
        if name.contains(where: { "0123456789".contains($0) }) {
            return "simd_\(name)"
        }
        else {
            return name
        }
//        switch self {
//        case .float2, .float3, .float4, .:
//            return "simd_\(name)"
//        default:
//            return name
//        }
    }
}

// Type,Size,Alignment,Aliases
// bool,1,1,
// char,1,1,int8_t
// unsigned char,1,1,"uchar,uint8_t"
// short,2,2,int16_t
// unsigned short,2,2,"ushort,unit16_t"
// int,4,4,int32_t
// unsigned int,4,4,"uint,uint32_t"
// half,2,2,
// float,4,4,
// bool2,2,2,
// bool3,4,4,
// bool4,4,4,
// char2,2,2,
// uchar2,2,2,
// char3,4,4,
// uchar3,4,4,
// char4,4,4,
// uchar4,4,4,
// short2,4,4,
// ushort2,4,4,
// short3,8,8,
// ushort3,8,8,
// short4,8,8,
// ushort4,8,8,
// int2,8,8,
// uint2,8,8,
// int3,16,16,
// uint3,16,16,
// int4,16,16,
// uint4,16,16,
// half2,4,4,
// half3,8,8,
// half4,8,8,
// float2,8,8,
// float3,16,16,
// float4,16,16,
// packed_char2,2,1,
// packed_uchar2,2,1,
// packed_char3,3,1,
// packed_uchar3,3,1,
// packed_char4,4,1,
// packed_uchar4,4,1,
// packed_short2,4,2,
// packed_ushort2,4,2,
// packed_short3,6,2,
// packed_ushort3,6,2,
// packed_short4,8,2,
// packed_ushort4,8,2,
// packed_int2,8,4,
// packed_uint2,8,4,
// packed_int3,12,4,
// packed_uint3,12,4,
// packed_int4,16,4,
// packed_uint4,16,4,
// packed_half2,4,2,
// packed_half3,6,2,
// packed_half4,8,2,
// packed_float2,8,4,
// packed_float3,12,4,
// packed_float4,16,4,
// half2x2,8,4,
// half2x3,16,8,
// half2x4,16,8,
// half3x2,12,4,
// half3x3,24,8,
// half3x4,24,8,
// half4x2,16,4,
// half4x3,32,8,
// half4x4,32,8,
// float2x2,16,8,
// float2x3,32,16,
// float2x4,32,16,
// float3x2,24,8,
// float3x3,48,16,
// float3x4,48,16,
// float4x2,32,8,
// float4x3,64,16,
// float4x4,64,
