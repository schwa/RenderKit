import Everything
import ModelIO

// TODO: Move
extension MetalType {
    init(_ format: MDLVertexFormat) {
        switch format {
        case .float2:
            self = .float2
        case .float3:
            self = .float3
        case .float4:
            self = .float4
        default:
            unimplemented()
        }
    }
}
