import Foundation
import Metal

@resultBuilder
struct StageBuilder {
    static func buildBlock(_ function: Function, _ components: Parameter...) -> ConcreteStage {
        return ConcreteStage(function: function, parameters: components)
    }
}

struct ConcreteStage: VertexStage, FragmentStage {
    let function: Function
    let parameters: [any Parameter]
}

//-enable-experimental-feature VariadicGenerics

protocol Parameter {
}

enum ParameterKind {
    case texture
    case sampler
    case vertices
    case argumentBuffer
}

struct ParameterIndex: RawRepresentable, Equatable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension ParameterIndex: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.rawValue = value
    }
}

// MARK: -

protocol RenderPipeline {
}

protocol VertexStage {
}

protocol FragmentStage {
}

struct TextureReference: Parameter {
    let index: ParameterIndex
    enum Value {
        case keyPath(PartialKeyPath<RenderEnvironment>)
        case texture(MTLTexture)
    }
    let texture: Value

    init<T>(index: T, texture: PartialKeyPath<RenderEnvironment>) where T: RawRepresentable, T.RawValue == ParameterIndex {
        self.index = index.rawValue
        self.texture = .keyPath(texture)

    }
}

struct VerticesReference: Parameter {
    let index: Any
    let vertices: PartialKeyPath<RenderEnvironment>
}

struct ArgumentBufferBinding: Parameter {
    let index: Any
    let buffer: PartialKeyPath<RenderEnvironment>
}

struct Function: Parameter {
    let named: Any
}

struct FunctionConstant: Parameter {
    let index: Any
    let value: Any
}

enum CommonBindings: ParameterIndex {
    case verticesBuffer = 1
    case transformsBuffer = 2
    case debug = 3
}

enum BlinnPhongBindings: ParameterIndex {
    case lightingModelArgumentBuffer = 1
    case materialsArgumentBuffer = 2
    case blinnPhongModeConstant = 3
}

struct RenderEnvironment {
    let transforms = ""
    let vertices = ""
    let lightingModel = ""
    let materials = ""
}


struct BlinnPhong: RenderPipeline {

    let debug = false

    @StageBuilder
    var vertexStage: some VertexStage {
        Function(named: "BlinnPhongVertexShader")
        TextureReference(index: CommonBindings.verticesBuffer, texture: \.transforms)
        VerticesReference(index: CommonBindings.transformsBuffer, vertices: \.vertices)
    }

    @StageBuilder
    var fragmentStage: some FragmentStage {
        Function(named: "BlinnPhongFragmentShader")
        ArgumentBufferBinding(index: BlinnPhongBindings.lightingModelArgumentBuffer, buffer: \.lightingModel)
        ArgumentBufferBinding(index: BlinnPhongBindings.materialsArgumentBuffer, buffer: \.materials)
        FunctionConstant(index: BlinnPhongBindings.blinnPhongModeConstant, value: 0)
        FunctionConstant(index: CommonBindings.debug, value: debug)
    }
}

