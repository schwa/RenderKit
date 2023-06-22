import Combine
import Everything
import Foundation
import Metal
import MetalKit
import MetalSupport
import os
import QuartzCore
import simd
import SwiftUI
import RenderKitSupport

// swiftlint:disable file_length

// TODO: Move & cleanup
func makeLabel(_ rootLabel: String?, _ label: String?, _ label2: String? = nil) -> String {
    String([rootLabel, label, label2].compactMap { $0 }.joined(separator: "."))
}

private let logger: Logger? = Logger(subsystem: "Renderer", category: "Renderer")

public protocol ParameterValuesProvider {
    mutating func setup(state: inout RenderState) throws
    func parameterValues() throws -> [RenderEnvironment.Key: ParameterValue]
}

public class Renderer<RenderGraph> where RenderGraph: RenderGraphProtocol {
    public let graph: RenderGraph
    public var label: String?
    public let commandQueue: MTLCommandQueue
    public /* private(set) */ var environment: RenderEnvironment // TODO: Make private

    private var submitters: [any RenderSubmitter] = []
    private var lock: OSAllocatedUnfairLock<RenderState>

    public enum Event {
        case didRender
    }

    private var eventsPassthrough = PassthroughSubject<Event, Never>()

    public var events: AnyPublisher<Event, Never> {
        eventsPassthrough.eraseToAnyPublisher()
    }

    private let queue = DispatchQueue(label: "RenderQueue", qos: .userInteractive, attributes: [])

    // MARK: Init & pre-render configuration

    public init(device: MTLDevice, graph: RenderGraph, environment: RenderEnvironment) {
        self.graph = graph
        commandQueue = device.makeCommandQueue()!
        commandQueue.label = makeLabel(label, "Command Queue")
        lock = .init(uncheckedState: RenderState(device: device, graph: graph))
        self.environment = environment
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
    }

    public func add(submitter: some RenderSubmitter) {
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        lock.withLockUnchecked { _ in
            submitters.append(submitter)
        }
    }

    public func update(drawableSize: CGSize) {
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public) ####")
        lock.withLockUnchecked { state in
            state.drawableSize = drawableSize
            state.setup = false
        }
    }

    // MARK: Per frame...

    public func render(drawable: CAMetalDrawable) throws {
//        logger?.debug("\(self.debugDescription, privacy: .public): Render")
        queue.async { [weak self] in
            guard let self else {
                return
            }
            do {
                try self._render(drawable: drawable)
            }
            catch {
                error.log()
            }
        }
    }

    private func _render(drawable: CAMetalDrawable) throws {
        try lock.withLockUnchecked { state in
            //        logger?.debug("\(self.debugDescription, privacy: .public): _render")
            if state.setup == false {
                try setup(drawable: drawable, state: &state)
            }
            guard state.setup == true else {
                logger?.warning("Failed to setup frame")
                return
            }
            for pass in graph.passes where pass.enabled {
                guard let pass = pass as? any RenderPassProtocol else {
                    continue
                }
                let activeSubmitters = submitters.filter { $0.shouldSubmit(pass: pass, environment: environment) }
                if activeSubmitters.isEmpty {
                    continue
                }
                for submitter in activeSubmitters {
                    try submitter.prepareRender(pass: pass, state: &state, environment: &environment)
                }
            }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                fatalError("Could not make command queue")
            }
            commandBuffer.label = makeLabel(label, "CommandBuffer")

            guard let depthTexture = state.cachedDepthTexture else {
                //                fatalError("No depth texture")
                logger?.debug("NO DEPTH TEXTURE SKIPPING")
                return
            }

            environment["$DRAWABLE_TEXTURE"] = .texture(drawable.texture)
            environment["$DEPTH_TEXTURE"] = .texture(depthTexture)

            var lastPassConfiguration: RenderPassOptions?

            for pass in graph.passes where pass.enabled {
                if let pass = pass as? any RenderPassProtocol {
                    var environment = self.environment
                    let activeSubmitters = submitters.filter { $0.shouldSubmit(pass: pass, environment: environment) }
                    if activeSubmitters.isEmpty {
                        continue
                    }
                    let renderPassDescriptor = MTLRenderPassDescriptor()
                    if let configuration = pass.configuration {
                        if let depthAttachment = configuration.depthAttachment {
                            renderPassDescriptor.depthAttachment = MTLRenderPassDepthAttachmentDescriptor(depthAttachment, environment: environment)
                        }
                        for (index, colorAttachment) in (configuration.colorAttachments ?? []).enumerated() {
                            renderPassDescriptor.colorAttachments[index] = MTLRenderPassColorAttachmentDescriptor(colorAttachment, environment: environment)
                        }
                    }
                    guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                        fatalError("Could not make encoder")
                    }
                    commandEncoder.label = makeLabel(label, pass.label, "Command Encoder")
                    try configure(commandEncoder: commandEncoder, forPass: pass, lastPassConfiguration: &lastPassConfiguration, state: &state)
                    for submitter in activeSubmitters {
                        try submitter.submit(pass: pass, state: state, environment: &environment, commandEncoder: commandEncoder)
                    }
                    self.environment = environment
                    commandEncoder.endEncoding()
                }
                else if let pass = pass as? any ComputePassProtocol {
                    guard let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                        fatalError("Could not make encoder")
                    }
                    computeCommandEncoder.label = makeLabel(label, pass.label, "Compute Command Encoder")
                    try encodeComputePass(commandEncoder: computeCommandEncoder, pass: pass, state: &state)
                    computeCommandEncoder.endEncoding()
                }
            }

            commandBuffer.present(drawable)
            DispatchQueue.main.async {
                commandBuffer.commit()
            }

            eventsPassthrough.send(.didRender)
        }
    }

    private func configure(commandEncoder: MTLRenderCommandEncoder, forPass pass: some RenderPassProtocol, lastPassConfiguration: inout RenderPassOptions?, state: inout RenderState) throws {
        // logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        lock.precondition(.owner)
        assert(state.setup == true)

        guard let renderPipelineState = state.cachedRenderPipelineStates[pass.id] else {
            fatalError("No render pipeline state for \(pass.id), got \(state.cachedRenderPipelineStates.keys)).")
        }
        commandEncoder.setRenderPipelineState(renderPipelineState)

        // Use the current configuration if there is one, Otherwise last one. Otherwise default one.
        var configuration: RenderPassOptions?
        if pass.configuration == nil {
            configuration = lastPassConfiguration
        }
        else {
            configuration = pass.configuration
        }
        if configuration == nil {
            configuration = RenderPassOptions()
        }
        lastPassConfiguration = configuration

        guard let options = configuration else {
            fatalError("No configuration")
        }

        commandEncoder.setFrontFacing(.init(options.frontFacing))
        commandEncoder.setTriangleFillMode(.init(options.fillMode))
        commandEncoder.setCullMode(.init(options.cullMode))

        guard let depthStencilState = state.cachedDepthStencilStates[options.depthStencil] else {
            fatalError("No cached depth stencil state")
        }
        commandEncoder.setDepthStencilState(depthStencilState)
    }

    // MARK: -

    private func setup(drawable: CAMetalDrawable, state: inout RenderState) throws {
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        lock.precondition(.owner)
        assert(state.setup == false)

        updateDepthTexture(state: &state)
        for pass in graph.passes where pass.enabled {
            guard let pass = pass as? any RenderPassProtocol else {
                continue
            }
            try setup(renderPass: pass, drawable: drawable, state: &state)
        }
        state.setup = true
    }

    private func updateDepthTexture(state: inout RenderState) {
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        lock.precondition(.owner)
        assert(state.setup == false)

        let width = Int(state.drawableSize.width)
        let height = Int(state.drawableSize.height)

        guard width > 0, height > 0 else {
            return
        }

        if width == state.cachedDepthTexture?.width && height == state.cachedDepthTexture?.height {
            warning("Depth texture (\(String(describing: state.cachedDepthTexture?.width)), \(String(describing: state.cachedDepthTexture?.height))) at incorrect size \(state.drawableSize)")
            return
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = .renderTarget
        textureDescriptor.resourceOptions = .storageModePrivate

        // textureDescrxiptor.resourceOptions = .storageModeMemoryless
        assertNotInRenderLoop("Creating depth texture.")
        let depthTexture = state.device.makeTexture(descriptor: textureDescriptor)!
        depthTexture.label = makeLabel(label, "Depth Texture")
        state.cachedDepthTexture = depthTexture
    }

    private func setup(renderPass pass: some RenderPassProtocol, drawable: CAMetalDrawable, state: inout RenderState) throws {
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        let activeSubmitters = submitters.filter { $0.shouldSubmit(pass: pass, environment: environment) }
        if activeSubmitters.isEmpty {
            return
        }

        if let configuration = pass.configuration, state.cachedDepthStencilStates[configuration.depthStencil] == nil {
            let descriptor = MTLDepthStencilDescriptor(configuration.depthStencil)
            descriptor.label = makeLabel(label, "Depth Stencil Descriptor")
            let depthStencilState = state.device.makeDepthStencilState(descriptor: descriptor)
            state.cachedDepthStencilStates[configuration.depthStencil] = depthStencilState
        }

        let vertexFunction = try state.cachedFunctionsByStage[pass.vertexStage.id] ?? cacheFunction(stage: pass.vertexStage, state: &state)
        let fragmentFunction = try state.cachedFunctionsByStage[pass.fragmentStage.id] ?? cacheFunction(stage: pass.fragmentStage, state: &state)

        if state.cachedRenderPipelineStates[pass.id] == nil {
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction

            let attributes = vertexFunction.vertexAttributes!
            renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(attributes: attributes)

            assert(drawable.texture.pixelFormat != .invalid)
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = drawable.texture.pixelFormat
            if let depthTexture = state.cachedDepthTexture {
                assert(depthTexture.pixelFormat != .invalid)
                renderPipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
            }
            renderPipelineDescriptor.label = makeLabel(label, "Pipeline State")

            let renderPipelineState = try state.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            state.cachedRenderPipelineStates[pass.id] = renderPipelineState
        }

        for submitter in activeSubmitters {
            try submitter.setup(state: &state)
        }
    }

    // MARK: Misc

    private func cacheFunction(stage: some StageProtocol, state: inout RenderState) throws -> MTLFunction {
        lock.precondition(.owner)
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        if state.setup == true {
            logger?.warning("Caching functions when already setup. Potential perf issue?")
        }

        let library: MTLLibrary
        let function: MTLFunction

        switch stage.function.library {
        case .default:
            library = try self.library(state: &state) // TODO: Rename default library
        case .manual(let libraryx):
            library = libraryx
//        case .compiled(let source, let options):
//            library = try device.makeLibrary(source: source, options: options)
        }

//        logger?.debug("\(self.debugDescription, privacy: .public): Make function \(stage.function.functionName)")
        if !stage.functionConstants.isEmpty {
            let constants = try MTLFunctionConstantValues(constants: stage.functionConstants)
            function = try library.makeFunction(name: stage.function.functionName, constantValues: constants)
        }
        else {
            function = try library.makeFunction(name: stage.function.functionName).safelyUnwrap(UndefinedError("Could not make function named: \(stage.function.functionName)"))
        }
        if let label = stage.function.label {
            function.label = label
        }
        state.cachedFunctionsByStage[stage.id] = function
        return function
    }

    func library(state: inout RenderState) throws -> MTLLibrary {
        if let cachedLibrary = state.cachedLibrary {
            return cachedLibrary
        }
        else {
            let library = try state.device.makeDefaultLibrary(bundle: .renderKitShadersModule)
            library.label = makeLabel(label, "Bundle.main default library")
            state.cachedLibrary = library
            return library
        }
    }
}

// MARK: -

extension Renderer: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Renderer(\(label.map({ "\"\($0)\"" }) ?? ""))"
    }
}

// MARK: -

private extension Renderer {
    func encodeComputePass(commandEncoder: MTLComputeCommandEncoder, pass: some ComputePassProtocol, state: inout RenderState) throws {
        logger?.debug("\(self.debugDescription, privacy: .public): \(#function, privacy: .public)")
        let key = pass.id
        // swiftlint:disable:next implicitly_unwrapped_optional
        var computePipelineState: MTLComputePipelineState! = state.cachedComputePipelineStates[key]
        let stage = pass.stages.first!
        if computePipelineState == nil {
            let function = try cacheFunction(stage: pass.computeStage, state: &state)
            computePipelineState = try state.device.makeComputePipelineState(function: function)
            state.cachedComputePipelineStates[key] = computePipelineState
        }
        commandEncoder.setComputePipelineState(computePipelineState)

        for input in stage.parameters {
            switch input.value {
            case .variable(let key):
                guard let value = environment[key] else {
                    fatalError("X: \(key) not found")
                    continue
                }
                try commandEncoder.setParameterValue(value, binding: input.binding)
            case .constant(let value):
                switch value {
                case .float2(let value):
                    commandEncoder.setBytes(of: value, index: try input.binding.bufferIndex)
                default:
                    fatalError("Unexpected case")
                }
            }
        }

        // NOTE: This code needs to move to thread
        var workSize = ComputeWorkSize(pipelineState: computePipelineState)
        workSize.configure(workSize: pass.workSize)
        guard let threadsPerGrid = workSize.threadsPerGrid, let threadsPerThreadGroup = workSize.threadsPerThreadGroup else {
            fatalError("Could not get work size info.")
        }
        if state.device.supportsNonuniformThreadGroupSizes {
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        }
        else {
            commandEncoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        }
    }
}

// MARK: Support

public extension MTLRenderCommandEncoder {
    func set(environment: RenderEnvironment, forPass pass: some PassProtocol) throws {
        for stage in pass.stages {
            let mtlStage = stage.kind.mtlRenderStages
            for input in stage.parameters {
                switch input.value {
                case .variable(let key):
                    guard let value = environment[key] else {
                        warning("\(key) not found")
                        return
                    }
                    if case .accessor = value {
                        pushDebugGroup(key.rawValue)
                    }
                    try setParameterValue(value, stage: mtlStage, binding: input.binding)
                    if case .accessor = value {
                        popDebugGroup()
                    }
                case .constant(let value):
                    switch value {
                    case .float3(let value):
                        setBytes(of: value, stage: mtlStage, index: try input.binding.bufferIndex)
                    default:
                        fatalError("Unexpected case")
                    }
                }
            }
        }
    }
}

// MARK: -

// TODO: Remove?
// public struct ResourceBinding {
//    enum Resource {
//        case texture
//        case buffer
//        case samplerState
//    }
//
//    struct Binding: Hashable {
//        let resource: Resource
//        let stage: MTLRenderStages
//        let index: Int
//    }
//
//    let commandEncoder: MTLRenderCommandEncoder
//    var bindings: [Binding: MTLResource] = [:]
//
//    public init(commandEncoder: MTLRenderCommandEncoder) {
//        self.commandEncoder = commandEncoder
//    }
//
//    public mutating func setTexture(_ texture: MTLTexture, stage: MTLRenderStages, index: Int) {
//        let binding = Binding(resource: .texture, stage: stage, index: index)
//        let existing = bindings[binding]
//        if existing === texture {
//            return
//        }
//        bindings[binding] = texture
//        commandEncoder.setTexture(texture, stage: stage, index: index)
//    }
// }
