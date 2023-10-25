import Metal

public struct Compute {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue

    public init(device: MTLDevice) throws {
        self.device = device
        commandQueue = self.device.makeCommandQueue()!
    }

    public func task<R>(_ block: (Task) throws -> R) rethrows -> R {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        defer {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        let task = Task(commandBuffer: commandBuffer)
        return try block(task)
    }

    public func makePass(function: ShaderFunction, constants: [String: Argument] = [:], arguments: [String: Argument] = [:]) throws -> Pass {
        try Pass(device: device, function: function, constants: constants, arguments: arguments)
    }
}

// MARK: -

public extension Compute {
    struct Pass {
        public let function: ShaderFunction
        fileprivate let bindings: [String: Int]
        public var arguments: Arguments
        public let computePipelineState: MTLComputePipelineState

        init(device: MTLDevice, function: ShaderFunction, constants: [String: Argument] = [:], arguments: [String: Argument] = [:]) throws {
            self.function = function

            let constantValues = MTLFunctionConstantValues()
            for (name, constant) in constants {
                constant.constantValue(constantValues, name)
            }

            let library = try device.makeLibrary(function.library)

            let function = try library.makeFunction(name: function.name, constantValues: constantValues)
            let computePipelineDescriptor = MTLComputePipelineDescriptor()
            computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = false
            computePipelineDescriptor.computeFunction = function
            let reflection: MTLComputePipelineReflection?
            (computePipelineState, reflection) = try device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: [.argumentInfo])
            bindings = Dictionary(uniqueKeysWithValues: reflection!.bindings.map { binding in
                return (binding.name, binding.index)
            })

            self.arguments = Arguments(arguments: arguments)
        }

        public var maxTotalThreadsPerThreadgroup: Int {
            computePipelineState.maxTotalThreadsPerThreadgroup
        }

        public var threadExecutionWidth: Int {
            computePipelineState.threadExecutionWidth
        }

        func bind(_ commandEncoder: MTLComputeCommandEncoder) {
            for (name, value) in arguments.arguments {
                let index = bindings[name]!
                value.encode(commandEncoder, index)
            }
        }
    }

    @dynamicMemberLookup
    struct Arguments {
        var arguments: [String: Argument]

        public subscript(dynamicMember name: String) -> Argument? {
            get {
                return arguments[name]
            }
            set {
                arguments[name] = newValue
            }
        }
    }

    struct Argument {
        //var bindingType: MTLBindingType

        var encode: (MTLComputeCommandEncoder, Int) -> Void
        var constantValue: (MTLFunctionConstantValues, String) -> Void

        public static func int<T>(_ value: T) -> Self where T: BinaryInteger {
            return Argument { encoder, index in
                withUnsafeBytes(of: value) { buffer in
                    encoder.setBytes(buffer.baseAddress!, length: buffer.count, index: index)
                }
            }
            constantValue: { constants, name in
                withUnsafeBytes(of: value) { buffer in
                    // TODO: may not be .int if T isn't Int32
                    constants.setConstantValue(buffer.baseAddress!, type: .int, withName: name)
                }
            }
        }

        public static func bool(_ value: Bool) -> Self {
            return Argument { encoder, index in
                withUnsafeBytes(of: value) { buffer in
                    encoder.setBytes(buffer.baseAddress!, length: buffer.count, index: index)
                }
            }
            constantValue: { constants, name in
                withUnsafeBytes(of: value) { buffer in
                    constants.setConstantValue(buffer.baseAddress!, type: .bool, withName: name)
                }
            }
        }

        public static func buffer(_ buffer: MTLBuffer, offset: Int = 0) -> Self {
            return Argument { encoder, index in
                encoder.setBuffer(buffer, offset: offset, index: index)
            }
            constantValue: { _, _ in
                fatalError()
            }
        }

        public static func texture(_ texture: MTLTexture) -> Self {
            return Argument { encoder, index in
                encoder.setTexture(texture, index: index)
            }
            constantValue: { _, _ in
                fatalError()
            }
        }
    }

    struct Task {
        let commandBuffer: MTLCommandBuffer

        public func callAsFunction<R>(_ block: (Dispatcher) throws -> R) rethrows -> R {
            try run(block)
        }

        public func run <R>(_ block: (Dispatcher) throws -> R) rethrows -> R {
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            defer {
                commandEncoder.endEncoding()
            }
            let dispatcher = Dispatcher(commandEncoder: commandEncoder)
            return try block(dispatcher)
        }
    }

    struct Dispatcher {
        let commandEncoder: MTLComputeCommandEncoder

        public func callAsFunction(pass: Pass, threadgroupsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize) throws {
            try dispatch(pass: pass, threadgroupsPerGrid: threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }

        public func dispatch(pass: Pass, threadgroupsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize) throws {
            commandEncoder.setComputePipelineState(pass.computePipelineState)
            pass.bind(commandEncoder)
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
    }
}

extension Compute.Pass: CustomStringConvertible {
    public var description: String {
        return "Compute.Pass(function: \(function), arguments: \(arguments)"
    }
}
