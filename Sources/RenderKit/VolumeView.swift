import SwiftUI
import Metal
import MetalKit
import ModelIO

public struct VolumeView: View {
    
    @State
    var renderPass = VolumeRenderPass<MetalViewConfiguration>()
    
    public init() {
    }
    
    public var body: some View {
        RendererView(renderPass: $renderPass)
    }
}

struct VolumeRenderPass<Configuration>: RenderPass where Configuration: RenderKitConfiguration {
    mutating func resized(configuration: inout Configuration.Update, size: CGSize) {
        logger?.debug("\(#function)")
    }
    
    var scene: SimpleScene?
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    
    
    
    init() {
        let url = Bundle.main.resourceURL!.appendingPathComponent("StanfordVolumeData/CThead")
        let volumeData = VolumeData(directoryURL: url, size: [256, 256, 113])
        let load = try! volumeData.load()
        let texture = try! load(MTLCreateSystemDefaultDevice()!)
    }
    
    mutating func setup(configuration: inout Configuration.Update) {
        guard let device = configuration.device else {
            fatalError("No metal device")
        }
        do {
            if renderPipelineState == nil {
                let library = try! device.makeDefaultLibrary(bundle: .shaders)
                let constants = MTLFunctionConstantValues()
                let vertexFunction = library.makeFunction(name: "flatShaderVertexShader")!
                let fragmentFunction = try! library.makeFunction(name: "flatShaderFragmentShader", constantValues: constants)

                // TODO: This is silly...
                let plane = try! MTKMesh(mesh: Plane().toMDLMesh(extent: [2, 2, 0], allocator: MTKMeshBufferAllocator(device: device)), device: device)

                let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
                renderPipelineDescriptor.vertexFunction = vertexFunction
                renderPipelineDescriptor.fragmentFunction = fragmentFunction
                renderPipelineDescriptor.colorAttachments[0].pixelFormat = configuration.colorPixelFormat
                renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthStencilPixelFormat
                renderPipelineDescriptor.vertexDescriptor = MTLVertexDescriptor(plane.vertexDescriptor)
                renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            }

            if depthStencilState == nil {
                let depthStencilDescriptor = MTLDepthStencilDescriptor()
                depthStencilDescriptor.depthCompareFunction = .lessEqual
                depthStencilDescriptor.isDepthWriteEnabled = true
                depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
            }

        }
        catch {
            fatalError()
        }
        
    }
    
    func draw(configuration: Configuration.Draw, commandBuffer: MTLCommandBuffer) {
        do {
            print("draw")
            guard let renderPipelineState, let depthStencilState else {
                return
            }
            guard let renderPassDescriptor = configuration.currentRenderPassDescriptor, let size = configuration.size else {
                fatalError("No current render pass descriptor.")
            }
            commandBuffer.withRenderCommandEncoder(descriptor: renderPassDescriptor) { encoder in
                encoder.setRenderPipelineState(renderPipelineState)
                encoder.setDepthStencilState(depthStencilState)
            }
        }
        catch {
            logger?.error("Render error: \(error)")
        }
    }
}
