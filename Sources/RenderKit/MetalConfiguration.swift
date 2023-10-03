import Metal

public struct MetalConfiguration {
    // TODO: Fully expand this.
    public var colorPixelFormat: MTLPixelFormat
    public var depthStencilPixelFormat: MTLPixelFormat
    public var depthStencilStorageMode: MTLStorageMode
    public var clearDepth: Double
    public var preferredFramesPerSecond: Int
}
