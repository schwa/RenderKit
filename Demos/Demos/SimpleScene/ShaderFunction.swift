import Metal

@dynamicMemberLookup
public struct ShaderLibrary {
    public static var `default` = ShaderLibrary.bundle(.main)

    static func bundle(_ bundle: Bundle) -> Self {
        return Self(bundle: bundle)
    }

    var bundle: Bundle

    private init(bundle: Bundle) {
        self.bundle = bundle
    }

    public subscript(dynamicMember name: String) -> ShaderFunction {
        return ShaderFunction(library: self, name: name)
    }
}

public extension MTLDevice {
    func makeLibrary(_ library: ShaderLibrary) throws -> MTLLibrary {
        let bundle = Bundle.main
        return try makeDefaultLibrary(bundle: bundle)
    }
}

// MARK: -

public struct ShaderFunction: Identifiable {
    public let id = UUID()
    public let library: ShaderLibrary
    public let name: String
    public let constants: [ShaderConstant]

    public init(library: ShaderLibrary, name: String, constants: [ShaderConstant] = []) {
        self.library = library
        self.name = name
        self.constants = constants

        // MTLFunctionConstantValues
        // MTLDataType
    }
}

public struct ShaderConstant {
    var dataType: MTLDataType
    var accessor: ((UnsafeRawPointer) -> Void) -> Void

    public init<T>(dataType: MTLDataType, value: [T]) {
        self.dataType = dataType
        accessor = { (callback: (UnsafeRawPointer) -> Void) in
            value.withUnsafeBytes { pointer in
                callback(pointer.baseAddress!)
            }
        }
    }

    public init<T>(dataType: MTLDataType, value: T) {
        self.dataType = dataType
        accessor = { (callback: (UnsafeRawPointer) -> Void) in
            withUnsafeBytes(of: value) { pointer in
                callback(pointer.baseAddress!)
            }
        }
    }

    public func add(to values: MTLFunctionConstantValues, name: String) {
        accessor { pointer in
            values.setConstantValue(pointer, type: dataType, withName: name)
        }
    }
}
