import Combine
import Everything
import Metal
import simd

// TODO: Replace with CoderKey? KeyType? LibraryKey?
public protocol ShaderKey: Hashable, CustomStringConvertible {
    var rawValue: String { get }
    init?(rawValue: String)
}

public extension ShaderKey {
    var description: String {
        rawValue
    }
}

// MARK: -

// TODO: Replace with CoderKey?
public protocol TypeKey: Hashable, CustomStringConvertible {
    var rawValue: String { get }
    init?(rawValue: String)
}

public extension TypeKey {
    var description: String {
        rawValue
    }
}

// MARK: -

public protocol ParameterKey: Hashable, CustomStringConvertible {
    var rawValue: String { get }
    init?(rawValue: String)
}

public extension ParameterKey {
    var description: String {
        rawValue
    }
}

// MARK: -

public class ShaderLibrary {
    public var mtlLibrary: MTLLibrary
    public var types: [StructureDefinition]
    public var shaders: [Shader]

    public init(mtlLibrary: MTLLibrary, types: [StructureDefinition] = [], shaders: [Shader] = []) {
        self.mtlLibrary = mtlLibrary
        self.types = types
        self.shaders = shaders
    }
}

public extension ShaderLibrary {
    func addTypes(_ types: [StructureDefinition]) {
        self.types += types
    }

    func addShaders(_ shaders: [Shader]) {
        self.shaders += shaders
    }
}

public extension ShaderLibrary {
    var vertexShaders: [Shader] {
        shaders.filter { $0.type == .vertex }
    }

    var fragmentShaders: [Shader] {
        shaders.filter { $0.type == .fragment }
    }
}

// MARK: -

public extension ShaderLibrary {
    func validate() throws {
        for shader in shaders {
            for parameter in shader.parameters {
                let kind = parameter.kind
                if kind == .texture {
                    continue
                }
                guard let typeName = parameter.typeName else {
                    fatalError("Parameter has no type: \(parameter)")
                }
                guard types[typeName] != nil else {
                    fatalError("No type \(typeName) for parameter \(String(describing: parameter.typeName))")
                }
            }
        }
    }
}

// MARK: -

public extension ShaderLibrary {
    func configure(renderPipelineDescriptor: MTLRenderPipelineDescriptor, vertexShader: Shader?, fragmentShader: Shader?) throws {
        if let vertexShader = vertexShader {
            let vertexFunction = mtlLibrary.makeFunction(name: vertexShader.name.rawValue)
            renderPipelineDescriptor.vertexFunction = vertexFunction
            guard let verticesTypeName = vertexShader.parameters["vertices"]?.typeName else {
                fatalError("No vertices")
            }
            guard let verticesType = types[verticesTypeName] else {
                fatalError("No vertex type")
            }
            renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(structure: verticesType)
        }

        if let fragmentShader = fragmentShader {
            let fragmentFunction = mtlLibrary.makeFunction(name: fragmentShader.name.description)
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
        }
    }
}
