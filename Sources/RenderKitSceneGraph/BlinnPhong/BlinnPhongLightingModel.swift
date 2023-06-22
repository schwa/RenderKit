import Everything
import Metal
import MetalSupport
import Shaders
import RenderKit
import RenderKitSupport

// TODO: Make struct. Use "isUniquelYReferenced" to nuke cache as needed on copy
public class BlinnPhongLightingModel {
    public var lights: [Light] {
        didSet {
            guard oldValue.map(\.id) != lights.map(\.id) else {
                return
            }
            tryElseLog {
                _ = try updateLightsBuffer(device: device)
            }
        }
    }

    public var screenGamma: Float = 2.2 // NOTE: Move into render environment object?

    public var ambientLightColor: SIMD3<Float> = [1, 1, 1]

    // Caches
    // TODO: These caches need to be discarded if things ^ change
    var cachedLightingBuffer: MTLBuffer?
    var cachedLightsBuffer: MTLBuffer?
    var cachedArgumentEncoder: MTLArgumentEncoder?

    var device: MTLDevice

    public init(lights: [Light], device: MTLDevice) {
        self.lights = lights
        self.device = device
    }

    @discardableResult
    func updateLightsBuffer(device: MTLDevice) throws -> MTLBuffer {
        if cachedLightsBuffer == nil {
            cachedLightsBuffer = try device.makeBuffer(length: 4 * 4096, options: .storageModeShared).safelyUnwrap(UndefinedError())
            cachedLightsBuffer!.label = "Lights Buffer"
        }
        guard let lightsBuffer = cachedLightsBuffer else {
            fatalError("No lights buffer")
        }
        let lights = lights.map {
            BlinnPhongLight(lightPosition: $0.transform.translation, lightColor: $0.lightColor, lightPower: $0.lightPower)
        }
        try lights.withUnsafeBytes { source in
            if source.count > lightsBuffer.length {
                self.cachedLightsBuffer = try device.makeBuffer(length: lightsBuffer.length * 2, options: .storageModeShared).safelyUnwrap(UndefinedError())
                self.cachedLightsBuffer!.label = "Lights Buffer"
            }
            guard let lightsBuffer = self.cachedLightsBuffer else {
                fatalError("No lights buffer")
            }
            assert(source.count <= lightsBuffer.length)
            let destination = UnsafeMutableRawBufferPointer(start: lightsBuffer.contents(), count: lightsBuffer.length)
            source.copyBytes(to: destination)
        }
        return lightsBuffer
    }
}

// MARK: -

extension BlinnPhongLightingModel: ParameterValuesProvider {
    public func setup(state: inout RenderState) throws {
        let key: RenderEnvironment.Key = "$LIGHTING"

        if cachedArgumentEncoder == nil {
            cachedArgumentEncoder = try state.argumentEncoder(forParameterKey: key)
        }

        if cachedLightingBuffer == nil {
            let buffer = try state.device.makeBuffer(length: cachedArgumentEncoder!.encodedLength, options: []).safelyUnwrap(UndefinedError())
            buffer.label = "\(key) Argument Buffer"
            cachedLightingBuffer = buffer
        }

        if cachedLightsBuffer == nil {
            try updateLightsBuffer(device: state.device)
        }
    }

    public func parameterValues() throws -> [RenderEnvironment.Key: ParameterValue] {
        // NOTE: This is called every frame.
        // Most of this should only get called when lighting changes
        let key: RenderEnvironment.Key = "$LIGHTING"

        guard let lightingBuffer = cachedLightingBuffer, let argumentEncoder = cachedArgumentEncoder else {
            throw UndefinedError()
        }
        argumentEncoder.setArgumentBuffer(lightingBuffer, offset: 0)
        argumentEncoder.setBytesOf(screenGamma, index: 0)
        argumentEncoder.setBytesOf(UInt32(lights.count), index: 1)
        argumentEncoder.setBytesOf(ambientLightColor, index: 2)
        argumentEncoder.setBuffer(cachedLightsBuffer, offset: 0, index: 3)
        return [
            key: .argumentBuffer(lightingBuffer, [.read: [cachedLightsBuffer!]]),
        ]
    }
}

