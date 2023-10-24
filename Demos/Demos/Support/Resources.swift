import Foundation
import MetalKit

// TODO: all this is very experimental.

public protocol ResourceProtocol: Hashable, Sendable {
}

public extension ResourceProtocol {
    func `as`(_ type: any URLProviding.Type) -> (any URLProviding)? {
        self as? any URLProviding
    }
}

public protocol URLProviding: ResourceProtocol {
    var url: URL { get throws }
}

public protocol SynchronousLoadable: ResourceProtocol {
    associatedtype Content
    associatedtype Parameter
    func load(_ parameter: Parameter) throws -> Content
}

public extension SynchronousLoadable where Parameter == () {
    func load() throws -> Content {
        return try load(())
    }
}

public protocol AsynchronousLoadable: ResourceProtocol {
    associatedtype Content // TODO: Sendable?
    associatedtype Parameter
    func load(_ parameter: Parameter) async throws -> Content
}

public extension AsynchronousLoadable where Parameter == () {
    func load() async throws -> Content {
        return try await load(())
    }
}

// MARK: -

public enum BundleReference: Hashable, Sendable {
    enum Error: Swift.Error {
        case missingBundle
    }

    case main
    case byURL(URL)
    case byIdentifier(String)
}

public extension BundleReference {
    var exists: Bool {
        switch self {
        case .main:
            return true
        case .byURL(let url):
            return Bundle(url: url) != nil
        case .byIdentifier(let identifier):
            return Bundle(identifier: identifier) != nil
        }
    }

    var bundle: Bundle {
        get throws {
            switch self {
            case .main:
                return Bundle.main
            case .byURL(let url):
                guard let bundle = Bundle(url: url) else {
                    throw Error.missingBundle
                }
                return bundle
            case .byIdentifier(let identifier):
                guard let bundle = Bundle(identifier: identifier) else {
                    throw Error.missingBundle
                }
                return bundle
            }
        }
    }
}

// MARK: -

public struct BundleResourceReference {
    public var bundle: BundleReference
    public var name: String
    public var `extension`: String?

    public init(bundle: BundleReference, name: String, `extension`: String? = nil) {
        self.bundle = bundle
        self.name = name
        self.`extension` = `extension`
    }

    enum Error: Swift.Error {
        case missingResource
    }

    public var exists: Bool {
        return (try? bundle.bundle.url(forResource: name, withExtension: `extension`)) != nil
    }

    public var url: URL {
        get throws {
            guard let url = try bundle.bundle.url(forResource: name, withExtension: `extension`) else {
                throw Error.missingResource
            }
            return url
        }
    }
}

public extension BundleReference {
    func resource(named name: String, withExtension `extension`: String?) -> BundleResourceReference {
        return BundleResourceReference(bundle: self, name: name, extension: `extension`)
    }
}

// MARK: -

extension BundleResourceReference: URLProviding {
}

public extension MTKTextureLoader {
    func newTexture(resource: some ResourceProtocol, options: [Option: Any]? = nil) throws -> MTLTexture {
        if let resource = resource as? BundleResourceReference {
            return try newTexture(resource: resource, options: options)
        }

        if let resource = resource as? any URLProviding {
            return try newTexture(resource: resource, options: options)
        }
        else if let resource = resource as? any SynchronousLoadable {
            return try newTexture(resource: resource, options: options)
        }
        else {
            fatalError()
        }
    }

    func newTexture(resource: BundleResourceReference, options: [Option: Any]? = nil) throws -> MTLTexture {
        // TODO: Scale factor.
        // TODO: Options
        return try newTexture(name: resource.name, scaleFactor: 1.0, bundle: resource.bundle.bundle, options: options)
    }

    func newTexture(resource: some URLProviding, options: [Option: Any]? = nil) throws -> MTLTexture {
        let url = try resource.url
        return try newTexture(URL: url, options: options)
    }

    func newTexture(resource: some URLProviding, options: [Option: Any]? = nil) async throws -> MTLTexture {
        let url = try resource.url
        return try await newTexture(URL: url, options: options)
    }

    func newTexture <Resource>(resource: Resource, options: [Option: Any]? = nil) throws -> MTLTexture where Resource: SynchronousLoadable, Resource.Parameter == (), Resource.Content == Data {
        let data = Data(try resource.load())
        return try newTexture(data: data, options: options)
    }

    func newTexture <Resource>(resource: Resource, options: [Option: Any]? = nil) async throws -> MTLTexture where Resource: AsynchronousLoadable, Resource.Parameter == (), Resource.Content == Data {
        let data = Data(try await resource.load())
        return try await newTexture(data: data, options: options)
    }
}
