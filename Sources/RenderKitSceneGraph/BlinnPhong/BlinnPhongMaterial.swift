import Everything
import Metal
import MetalKit
import RenderKit

public class BlinnPhongMaterial: MaterialProtocol, Codable {
    public var ambient: MaterialParameter
    public var diffuse: MaterialParameter
    public var specular: MaterialParameter
    public var shininess: Float

    public var cachedArgumentBuffer: MTLBuffer?

    public init(ambient: MaterialParameter? = nil, diffuse: MaterialParameter, specular: MaterialParameter, shininess: Float) throws {
        self.ambient = ambient ?? diffuse
        self.diffuse = diffuse
        self.specular = specular
        self.shininess = shininess
    }

    public init(ambientColor: SIMD4<Float>? = nil, diffuseColor: SIMD4<Float>, specularColor: SIMD4<Float>, shininess: Float, device: MTLDevice) throws {
        ambient = try .init(color: ambientColor ?? diffuseColor, device: device, label: "ambientColor")
        diffuse = try .init(color: diffuseColor, device: device, label: "diffuseColor")
        specular = try .init(color: specularColor, device: device, label: "specularColor")
        self.shininess = shininess
    }

    enum CodingKeys: CodingKey {
        case ambient
        case diffuse
        case specular
        case shininess
    }

    var argumentEncoder: MTLArgumentEncoder?
}

extension BlinnPhongMaterial: ParameterValuesProvider {
    public func setup(state: inout RenderState) throws {
        let key: RenderEnvironment.Key = "$BLINN_PHONG_MATERIAL"

        if argumentEncoder == nil {
            argumentEncoder = try state.argumentEncoder(forParameterKey: key)
        }

        if cachedArgumentBuffer == nil {
            guard let argumentEncoder else {
                throw UndefinedError()
            }
            let buffer = try state.device.makeBuffer(length: argumentEncoder.encodedLength, options: []).safelyUnwrap(UndefinedError())
            buffer.label = "\(key) Argument Buffer"
            cachedArgumentBuffer = buffer
        }
    }

    public func parameterValues() throws -> [RenderEnvironment.Key: ParameterValue] {
        let key: RenderEnvironment.Key = "$BLINN_PHONG_MATERIAL"

        guard let argumentEncoder, let buffer = cachedArgumentBuffer else {
            throw UndefinedError("No argument encoder/cached argument buffer.")
        }

        argumentEncoder.setArgumentBuffer(buffer, offset: 0)
        argumentEncoder.setTexture(ambient.texture, index: 0)
        argumentEncoder.setSamplerState(ambient.samplerState, index: 1)
        argumentEncoder.setTexture(diffuse.texture, index: 2)
        argumentEncoder.setSamplerState(diffuse.samplerState, index: 3)
        argumentEncoder.setTexture(specular.texture, index: 4)
        argumentEncoder.setSamplerState(specular.samplerState, index: 5)
        let d = argumentEncoder.constantData(at: 6).bindMemory(to: Float.self, capacity: 1)
        d.pointee = shininess
        return [
            key: .argumentBuffer(buffer, [.read: [ambient.texture, diffuse.texture, specular.texture]]),
        ]
    }
}
