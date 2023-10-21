// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Metal
import MetalKit
import CoreGraphics
import Everything
import SIMDSupport
import TOMLKit
import UniformTypeIdentifiers

@main
struct Compute: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "TODO",
        subcommands: [Run.self, MetalInfo.self],
        defaultSubcommand: Run.self)
}

struct Run: AsyncParsableCommand {
    @Argument
    var config: String

    @Flag(name: .shortAndLong, help: "Enable logging.")
    var logging = false

    mutating func run() async throws {
        let configURL = URL(filePath: config)

        let logger: MyLogger? = logging == true ? MyLogger() : nil

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        var context = Context(device: device)
        context.logger = logger

        let config: Config
        switch configURL.pathExtension {
        case "json":
            logger?.info("Loading config from JSON file.")
            let decoder = JSONDecoder()
            decoder.allowsJSON5 = true
            let data = try Data(contentsOf: configURL)
            config = try decoder.decode(Config.self, from: data)
        case "toml":
            logger?.info("Loading config from TOML file.")
            let decoder = TOMLDecoder()
            let string = try String(contentsOf: configURL)
            config = try decoder.decode(Config.self, from: string)
        default:
            fatalError()
        }
        for action in config.actions {
            try await action.run(context: &context)
        }
    }
}

struct MetalInfo: AsyncParsableCommand {
    mutating func run() async throws {
        let device = MTLCreateSystemDefaultDevice()!
        print(device)
        print(device.supportsFunctionPointers)
    }
}

// MARK: -

struct Context {
    var device: MTLDevice
    var environment: [String: Value] = [:]
    var logger: MyLogger?
}

enum Value: Decodable {
    case int(Int)
    case key(String)
    case texture(MTLTexture)
    case buffer(MTLBuffer)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self = .int(value)
        }
        else if let value = try? container.decode(String.self) {
            self = .key(value)
        }
        else {
            fatalError("Cannot decode a value.")
        }
    }
}

extension Value {
    func resolve(type: Int.Type, context: Context) throws -> Int {
        switch self {
        case .int(let value):
            return value
        case .key(var key):
            var field: String?
            if key.contains(".") {
                let parts = key.split(separator: ".")
                assert(parts.count == 2)
                key = String(parts[0])
                field = String(parts[1])
            }
            guard let value = context.environment[key] else {
                fatalError("Could not find key \"\(key)\" in environment.")
            }
            switch (value, field) {
            case (.int(let value), _):
                return value
            case (.texture(let texture), "width"):
                return texture.width
            case (.texture(let texture), "height"):
                return texture.height
            case (.texture(let texture), "depth"):
                return texture.depth
            default:
                fatalError()
            }
        default:
            fatalError("Could not resolve type to int.")
        }
    }
}

// MARK: -

struct Config: Decodable {
    enum Version: String, Decodable {
        case v001 = "0.0.1"
    }

    var version: Version
    var actions: [any Action]

    enum CodingKeys: CodingKey {
        case version
        case actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(Version.self, forKey: .version)
        self.actions = try container.decode([AnyAction].self, forKey: .actions).map { $0.action }
    }
}

protocol Labeled {
    var label: String? { get set }
}

protocol Action: Decodable, Labeled {
    func run(context: inout Context) async throws
}

struct AnyAction: Decodable {
    enum Kind: String, Decodable {
        case loadTexture = "load_texture"
        case loadBuffer = "load_buffer"
        case createTexture = "create_texture"
        case compute
        case writeTexture = "write_texture"
    }
    var kind: Kind
    var action: any Action

    enum CodingKeys: CodingKey {
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .loadTexture:
            action = try LoadTextureAction(from: decoder)
        case .loadBuffer:
            action = try LoadBufferAction(from: decoder)
        case .createTexture:
            action = try CreateTextureAction(from: decoder)
        case .compute:
            action = try ComputeAction(from: decoder)
        case .writeTexture:
            action = try WriteTextureAction(from: decoder)
        }
    }
}

struct LoadTextureAction: Action {
    var label: String?
    var source: String
    var destination: String

    func run(context: inout Context) async throws {
        context.logger?.info("Loading texture from \"\(source)\".")
        let textureLoader = MTKTextureLoader(device: context.device)
        let sourceURL = URL(fileURLWithPath: source)
        let texture = try await textureLoader.newTexture(URL: sourceURL)
        context.logger?.info("Loaded \"\(texture)\".")
        context.environment[destination] = .texture(texture)
    }
}

//    [[actions]]
//    label = "Load buffer 0
//    destination = "buffer0"
//    [[actions.buffer]]
//    path = "buffer.txt"
//    mapping = { "0" = 0, "1" = 1 }

struct LoadAction: Action {
    enum CodingKeys: CodingKey {
        case label
        case destination
        case texture
        case buffer
    }

    var label: String?
    var destination: String
    var make: (Context) throws -> Value

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        destination = try container.decode(String.self, forKey: .destination)
        if let parameters = try container.decodeIfPresent(Parameters.self, forKey: .texture) {
            make = { _ in
                fatalError()
            }
        }
        else if let parameters = try container.decodeIfPresent(Parameters.self, forKey: .buffer) {
            make = { _ in
                fatalError()
            }
        }
        else {
            fatalError()
        }
    }

    struct Parameters: Decodable {
        enum CodingKeys: CodingKey {
            case path
            case mapping
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
        }
    }

//                if let path = try container.decodeIfPresent(String.self, forKey: .path) {
//                    let sourceURL = URL(fileURLWithPath: path)
//                    let type = UTType(filenameExtension: sourceURL.pathExtension)
//                    context.logger?.info("Loading buffer from \"\(path)\" of tyoe \(String(describing: type?.identifier)).")
//                    if type?.conforms(to: .commaSeparatedText) == true {
//                        fatalError()
//                    }
//                    if type?.conforms(to: .text) == true {
//                        let mapping = try container.decode([String: Int].self, forKey: .mapping)
//                        let string = try String(contentsOf: sourceURL)
//                        let lines = string.lines
//                        let type = try container.decode(String.self, forKey: .type)
//                        let values = lines.flatMap { line in
//                            line.map { character in
//                                let s = String(character)
//                                return mapping[s]!
//                            }
//                        }
//                        switch type.lowercased() {
//                        case "uint8":
//                            let values = values.map { UInt8($0) }
//                            return values.withUnsafeBytes { buffer in
//                                guard let buffer = context.device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
//                                    fatalError("Could not create buffer.")
//                                }
//                                return buffer
//                            }
//                        default:
//                            fatalError()
//                        }
//                    }
//                    else {
//                        let data = try Data(contentsOf: sourceURL)
//                        return data.withUnsafeBytes { buffer in
//                            guard let buffer = context.device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
//                                fatalError("Could not create buffer.")
//                            }
//                            return buffer
//                        }
//                    }
//                }
//            }
//        }
//    }

    func run(context: inout Context) async throws {
        fatalError()
    }
}

struct LoadBufferAction: Action {
    var label: String?
    var makeBuffer: (Context) throws -> MTLBuffer
    var destination: String

    enum CodingKeys: CodingKey {
        case label
        case path
        case inline
        case destination
        case mapping
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        if let path = try? container.decode(String.self, forKey: .path) {
            makeBuffer = { context in
                let sourceURL = URL(fileURLWithPath: path)
                let type = UTType(filenameExtension: sourceURL.pathExtension)
                context.logger?.info("Loading buffer from \"\(path)\" of tyoe \(String(describing: type?.identifier)).")
                if type?.conforms(to: .commaSeparatedText) == true {
                    fatalError()
                }
                if type?.conforms(to: .text) == true {
                    let mapping = try container.decode([String: Int].self, forKey: .mapping)
                    let string = try String(contentsOf: sourceURL)

                    let lines = string.lines

                    let type = try container.decode(String.self, forKey: .type)

                    let values = lines.flatMap { line in
                        line.map { character in
                            let s = String(character)
                            return mapping[s]!
                        }
                    }

                    switch type.lowercased() {
                    case "uint8":
                        let values = values.map { UInt8($0) }
                        return values.withUnsafeBytes { buffer in
                            guard let buffer = context.device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
                                fatalError("Could not create buffer.")
                            }
                            return buffer
                        }
                    default:
                        fatalError()
                    }
                }
                else {
                    let data = try Data(contentsOf: sourceURL)
                    return data.withUnsafeBytes { buffer in
                        guard let buffer = context.device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
                            fatalError("Could not create buffer.")
                        }
                        return buffer
                    }
                }
            }
        }
        else if let definition = try? container.decode(InlineBufferDefinition.self, forKey: .inline) {
            makeBuffer = { context in
                context.logger?.info("Loading buffer with definition.")
                return try context.device.makeBuffer(definition: definition)
            }
        }
        else {
            fatalError()
        }
        destination = try container.decode(String.self, forKey: .destination)
    }

    func run(context: inout Context) async throws {
        let buffer = try makeBuffer(context)
        context.environment[destination] = .buffer(buffer)
    }
}

struct CreateTextureAction: Action {
    var label: String?
    var size: Size
    var pixelFormat: String
    var destination: String

    func run(context: inout Context) async throws {
        let size = try size.resolve(context: context)
        let pixelFormat: MTLPixelFormat
        switch self.pixelFormat {
        case "bgra8Unorm":
            pixelFormat = .bgra8Unorm
        case "bgra8Unorm_srgb":
            pixelFormat = .bgra8Unorm_srgb
        default:
            fatalError()
        }
        context.logger?.info("Creating new texture of size \(String(describing: size)).")
        let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        outputTextureDescriptor.usage = .shaderWrite
        guard let texture = context.device.makeTexture(descriptor: outputTextureDescriptor) else {
            fatalError("Could not create texture.")
        }
        context.environment[destination] = .texture(texture)
    }
}

struct ComputeAction: Action {
    enum CodingKeys: String, CodingKey {
        case label
        case source
        case function
        case bindings
        case threadsPerGrid = "threads_per_grid"
        case threadsPerThreadgroup = "threads_per_threadgroup"
    }

    var label: String?
    var source: String
    var function: String?
    struct Binding: Decodable {
        var index: Int
        var key: String
        var offset: Int?
    }
    var bindings: [Binding]
    var threadsPerGrid: Size
    var threadsPerThreadgroup: Size

    func run(context: inout Context) async throws {
        let device = context.device
        let sourceURL = URL(fileURLWithPath: source)
        let library: MTLLibrary
        switch sourceURL.pathExtension {
        case "metal":
            context.logger?.info("Creating shader library from source at \"\(sourceURL)\".")
            let source = try String(contentsOf: sourceURL)
            library = try await device.makeLibrary(source: source, options: nil)
        case "metallib":
            context.logger?.info("Loading shader library at \"\(sourceURL)\".")
            library = try device.makeLibrary(URL: sourceURL)
        default:
            fatalError()
        }
        let functionName = function ?? sourceURL.deletingPathExtension().lastPathComponent
        context.logger?.info("Using kernel function named \"\(functionName)\".")
        guard let function = library.makeFunction(name: functionName) else {
            fatalError("Could not make function \"\(functionName)\".")
        }
        let pipelineState = try await device.makeComputePipelineState(function: function)
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError()
        }
        let start = CFAbsoluteTimeGetCurrent()
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError()
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError()
        }
        commandEncoder.setComputePipelineState(pipelineState)
        for binding in bindings {
            guard let value = context.environment[binding.key] else {
                fatalError("Could not get value for \"\(binding.key)\".")
            }
            switch value {
            case .texture(let texture):
                context.logger?.info("Binding texture \"\(binding.key)\" to index #\(binding.index).")
                commandEncoder.setTexture(texture, index: binding.index)
            case .buffer(let buffer):
                let offset = binding.offset ?? 0
                context.logger?.info("Binding buffer \"\(binding.key)\" to index #\(binding.index) with offset \(offset).")
                commandEncoder.setBuffer(buffer, offset: offset, index: binding.index)
            default:

                //commandEncoder.setThreadgroupMemoryLength(<#T##length: Int##Int#>, index: <#T##Int#>)

                fatalError("Could not bind \(value)")
            }
        }
        guard device.supportsNonUniformThreadgroupSize else {
            fatalError()
        }
        let threadsPerGrid = try threadsPerGrid.resolve(context: context)
        let threadsPerThreadgroup = try threadsPerThreadgroup.resolve(context: context)
        context.logger?.info("Dispatching with threads per grid: \(String(describing: threadsPerGrid)), thread per threadgroup: \(String(describing: threadsPerThreadgroup)).")
        commandEncoder.dispatchThreads(
            threadsPerGrid,
            threadsPerThreadgroup: threadsPerThreadgroup
        )
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let end = CFAbsoluteTimeGetCurrent()
        context.logger?.info("Command buffer completed: \((end - start).formatted()).")
    }
}

struct WriteTextureAction: Action {
    var label: String?
    var source: String
    var destination: String

    func run(context: inout Context) async throws {
        let value = context.environment[source]
        switch value {
        case .texture(let texture):
            context.logger?.info("Writing texture \(source) to \(destination).")
            let image = await texture.cgImage()
            let destinationURL = URL(fileURLWithPath: destination)
            try image.write(to: destinationURL)
        default:
            fatalError()
        }
    }
}

struct Size: Decodable {
    var width: Value
    var height: Value
    var depth: Value

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let values = try container.decode([Value].self)
        switch values.count {
        case 1:
            (width, height, depth) = (values[0], .int(1), .int(1))
        case 2:
            (width, height, depth) = (values[0], values[1], .int(1))
        case 3:
            (width, height, depth) = (values[0], values[1], values[2])
        default:
            fatalError()
        }
    }
}

extension Size {
    func resolve(context: Context) throws -> MTLSize {
        let width = try width.resolve(type: Int.self, context: context)
        let height = try height.resolve(type: Int.self, context: context)
        let depth = try depth.resolve(type: Int.self, context: context)
        return MTLSize(width: width, height: height, depth: depth)
    }
}

enum InlineBufferDefinition: Decodable {
    case int32([Int32])

    enum CodingKeys: CodingKey {
        case type
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "int32":
            self = .int32(try container.decode([Int32].self, forKey: .values))
        default:
            fatalError()
        }
    }
}

extension MTLDevice {
    func makeBuffer(definition: InlineBufferDefinition) throws -> MTLBuffer {
        switch definition {
        case .int32(let values):
            values.withUnsafeBytes { buffer in
                guard let buffer = makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
                    fatalError()
                }
                return buffer
            }
        }
    }
}

struct MyLogger {
    func info(_ message: String) {
        let standardError = FileHandle.standardError
        var stream = ""
        print(message, to: &stream)
        let data = stream.data(using: .utf8)
        standardError.write(data!)
    }
}

extension String {
    var lines: [String] {
        var lines: [String] = []
        enumerateLines { line, _ in
            lines.append(line)
        }
        return lines
    }
}

enum BufferBuilder {
    case binaryFile(url: URL)
    case textFile(url: URL, mapping: [String: Int])
    case csvFile(url: URL)
}

extension MTLDevice {
    func makeBuffer(_ parameters: LoadAction.Parameters) throws -> MTLBuffer {
        fatalError()

        //                if let path = try container.decodeIfPresent(String.self, forKey: .path) {
        //                    let sourceURL = URL(fileURLWithPath: path)
        //                    let type = UTType(filenameExtension: sourceURL.pathExtension)
        //                    context.logger?.info("Loading buffer from \"\(path)\" of tyoe \(String(describing: type?.identifier)).")
        //                    if type?.conforms(to: .commaSeparatedText) == true {
        //                        fatalError()
        //                    }
        //                    if type?.conforms(to: .text) == true {
        //                        let mapping = try container.decode([String: Int].self, forKey: .mapping)
        //                        let string = try String(contentsOf: sourceURL)
        //                        let lines = string.lines
        //                        let type = try container.decode(String.self, forKey: .type)
        //                        let values = lines.flatMap { line in
        //                            line.map { character in
        //                                let s = String(character)
        //                                return mapping[s]!
        //                            }
        //                        }
        //                        switch type.lowercased() {
        //                        case "uint8":
        //                            let values = values.map { UInt8($0) }
        //                            return values.withUnsafeBytes { buffer in
        //                                guard let buffer = context.device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
        //                                    fatalError("Could not create buffer.")
        //                                }
        //                                return buffer
        //                            }
        //                        default:
        //                            fatalError()
        //                        }
        //                    }
        //                    else {
        //                        let data = try Data(contentsOf: sourceURL)
        //                        return data.withUnsafeBytes { buffer in
        //                            guard let buffer = context.device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: []) else {
        //                                fatalError("Could not create buffer.")
        //                            }
        //                            return buffer
        //                        }
        //                    }
        //                }

    }
}
