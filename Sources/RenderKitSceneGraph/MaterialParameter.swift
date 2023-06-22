import Everything
import Metal
import MetalKit
import RenderKitSupport

public struct MaterialParameter: Codable {
    public private(set) var provider: MaterialProvider?
    public let kind: Kind
    public let buffer: MTLBuffer?
    public let texture: MTLTexture
    public let samplerDescriptor: MTLSamplerDescriptor
    public let samplerState: MTLSamplerState

    public enum Kind {
        case color(SIMD4<Float>)
        case texture
    }

    public init(named name: String, bundle: Bundle? = nil, device: MTLDevice) throws {
        assertNotInRenderLoop()
        kind = .texture
        buffer = nil
        let loader = MTKTextureLoader(device: device)
        texture = try loader.newTexture(name: name, scaleFactor: 1, bundle: bundle, options: nil)
        texture.label = name
        samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.supportArgumentBuffers = true // NOTE: Is this inefficient to keep as true?
        samplerDescriptor.label = name
        // TODO: sampler parameters
        samplerState = try device.makeSamplerState(descriptor: samplerDescriptor)
            .safelyUnwrap(UndefinedError("Could not create sampler."))
    }

    public init(url: URL, device: MTLDevice) throws {
        assertNotInRenderLoop()
        kind = .texture
        buffer = nil
        let loader = MTKTextureLoader(device: device)
        texture = try loader.newTexture(URL: url, options: nil)
        texture.label = url.path
        samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.supportArgumentBuffers = true // NOTE: Is this inefficient to keep as true?
        samplerDescriptor.label = url.path
        // TODO: sampler parameters
        samplerState = try device.makeSamplerState(descriptor: samplerDescriptor)
            .safelyUnwrap(UndefinedError("Could not create sampler."))
    }

    public init(provider: MaterialProvider, device: MTLDevice) throws {
        switch provider {
        case .direct:
            fatalError("Unexpected case")
        case .url(let url):
            self = try MaterialParameter(url: url, device: device)
        case .resource(let name, let bundleSpecifier):
            let bundle = bundleSpecifier?.bundle
            self = try MaterialParameter(named: name, bundle: bundle, device: device)
        case .color(let color):
            self = try MaterialParameter(color: color, device: device)
        }
        self.provider = provider
    }

    public init(color: SIMD4<Float>, device: MTLDevice, label: String? = nil) throws {
        provider = .color(color: color)
        kind = .color(color)
        let pixelFormat = MTLPixelFormat.rgba32Float

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.width = 1
        descriptor.height = 1
        descriptor.depth = 1
        descriptor.storageMode = .shared
        assertNotInRenderLoop()

        let texture = device.makeTexture(descriptor: descriptor)!
        texture.label = label
        withUnsafeBytes(of: color) { buffer in
            texture.replace(region: MTLRegion(origin: .zero, size: [1, 1, 1]), mipmapLevel: 0, withBytes: buffer.baseAddress!, bytesPerRow: pixelFormat.size!)
        }
        texture.label = "Color.\(colorToString(color))"

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.supportArgumentBuffers = true // NOTE: Is this inefficient to keep as true?
        samplerDescriptor.label = "Color.\(colorToString(color))"
        // TODO: sampler parameters
        assertNotInRenderLoop()
        let samplerState = try device.makeSamplerState(descriptor: samplerDescriptor)
            .safelyUnwrap(UndefinedError("Could not create sampler."))

        self.texture = texture
        buffer = nil
        self.samplerDescriptor = samplerDescriptor
        self.samplerState = samplerState
    }

    enum CodingKeys: CodingKey {
        case provider
    }

    public init(from decoder: Decoder) throws {
        let provider = try MaterialProvider(from: decoder)
        self = try MaterialParameter(provider: provider, device: MTLCreateYoloDevice())
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        // TODO: try container.encode(samplerDescriptor, forKey: .samplerDescriptor)
        warning("Not encoding sampler")
    }
}

public extension MaterialParameter {
    static func color(_ color: SIMD4<Float>, device: MTLDevice, label: String? = nil) throws -> MaterialParameter {
        try MaterialParameter(color: color, device: device, label: label)
    }
}

public enum MaterialProvider: Codable {
    case direct
    case url(url: URL)
    case resource(name: String, bundleSpecifier: BundleSpecifier?)
    case color(color: SIMD4<Float>)
}

func colorToString(_ color: SIMD4<Float>) -> String {
    color.map { (channel: Float) -> String in
        String(Int(channel * 255.0), radix: 16)
    }
    .joined()
}

// Note: Move to Everything
public extension NSRegularExpression {
    func firstMatch(in string: String, options: NSRegularExpression.MatchingOptions) -> NSTextCheckingResult? {
        firstMatch(in: string, options: options, range: NSRange(string.startIndex ..< string.endIndex, in: string))
    }
}

