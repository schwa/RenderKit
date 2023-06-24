import Metal
import RenderKitSupport

/// RenderGraphs merely contain Passes
public protocol RenderGraphProtocol {
    var passes: [any PassProtocol] { get }
}

/// Passes contain Stages.
public protocol PassProtocol: Identifiable, Labelled {
    var enabled: Bool { get }
    var stages: [any StageProtocol] { get }
    var selectors: Set<PassSelector> { get }
}

public protocol RenderPassProtocol: PassProtocol {
    associatedtype VertexStage: VertexStageProtocol
    associatedtype FragmentStage: FragmentStageProtocol
    var configuration: RenderPassOptions? { get }
    var vertexStage: VertexStage { get }
    var fragmentStage: FragmentStage { get }
}

public protocol ComputePassProtocol: PassProtocol {
    associatedtype ComputeStage: ComputeStageProtocol
    var workSize: MTLSize { get } // NOTE: This should probably not be in the pass?
    var computeStage: ComputeStage { get }
}

/// Stages contain Functions
public protocol StageProtocol: Identifiable {
    var function: FunctionProvider { get }
    var parameters: [Parameter] { get }
    var functionConstants: [FunctionConstant] { get }
    var kind: ShaderStageKind { get }
}

public protocol RenderStageProtocol: StageProtocol {
}

public protocol VertexStageProtocol: RenderStageProtocol {
}

public protocol FragmentStageProtocol: RenderStageProtocol {
}


/// RenderSubmitters submit geometry to be rendered by stages.
public protocol RenderSubmitter {
    /// Called before any rendering
    func setup(state: inout RenderState) throws

    /// Called before prepareRender and submit
    func shouldSubmit(pass: some RenderPassProtocol, environment: RenderEnvironment) -> Bool

    /// Called at beginning of render pass
    func prepareRender(pass: some RenderPassProtocol, state: inout RenderState, environment: inout RenderEnvironment) throws

    /// Called per render pas
    func submit(pass: some RenderPassProtocol, state: RenderState, environment: inout RenderEnvironment, commandEncoder: MTLRenderCommandEncoder) throws
}

// MARK: Render

public protocol ComputeStageProtocol: StageProtocol {
}

public enum LibraryProvider {
    case `default`
    // case compiled(source: String, options: MTLCompileOptions? = nil)
    case manual(MTLLibrary)
}

public struct FunctionProvider {
    //    case name(String)
    //    case source(String)

    public let functionName: String
    public let library: LibraryProvider
    public let label: String?

    public init(functionName: String, library: LibraryProvider, label: String? = nil) {
        self.functionName = functionName
        self.library = library
        self.label = label
    }

    public static func name(_ functionName: String) -> FunctionProvider {
        FunctionProvider(functionName: functionName, library: .default)
    }
}

// MARK: -

public extension PassProtocol {
    var enabled: Bool { true }
    var selectors: Set<PassSelector> { [] }
}

public extension RenderPassProtocol {
    var configuration: RenderPassOptions? {
        .default
    }

    var stages: [any StageProtocol] {
        [vertexStage, fragmentStage]
    }
}

public extension ComputePassProtocol {
    var stages: [any StageProtocol] {
        [computeStage]
    }
}

public extension StageProtocol {
    var parameters: [Parameter] { [] }
    var functionConstants: [FunctionConstant] { [] }
}

public extension VertexStageProtocol {
    var kind: ShaderStageKind { .vertex }
}

public extension FragmentStageProtocol {
    var kind: ShaderStageKind { .fragment }
}

public extension ComputeStageProtocol {
    var kind: ShaderStageKind { .compute }
}

public extension PassProtocol {
    var label: String? { String(describing: "\(type(of: self))") }
}
