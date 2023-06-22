import Metal

extension MTLFunctionConstantValues {
    convenience init(constants: [FunctionConstant]) throws {
        self.init()
        for constant in constants {
            switch constant.value {
            case .int(var value):
                setConstantValue(&value, type: .int, index: try constant.binding.constantIndex)
            default:
                fatalError("Unexpected case")
            }
        }
    }
}

extension ShaderStageKind {
    var mtlRenderStages: MTLRenderStages {
        switch self {
        case .vertex:
            return .vertex
        case .fragment:
            return .fragment
        case .tile:
            return .tile
        default:
            fatalError("Unexpected case")
        }
    }
}
