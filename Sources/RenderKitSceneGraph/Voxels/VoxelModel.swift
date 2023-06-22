import Everything
import Foundation
import Metal
import MetalSupport
import Shaders
import RenderKitSupport

public class VoxelModel {
    public let vertexBuffer: MTLBuffer
    public let indexBuffer: MTLBuffer
    public let indexCount: Int
    public let colorPalette: MTLTexture

    public init(model: MagicaVoxelModel, device: MTLDevice) throws {
        // testBuilder()

        let maxVertexCount = model.voxels.count * 4 * 6
        // 2 triangles, 3 vertices, 6 sides
        let maxIndexCount = model.voxels.count * 2 * 3 * 6

        let voxelBuffer = device.makeBuffer(bytesOf: model.voxels, options: .storageModeShared)

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = Int(model.size.x)
        textureDescriptor.height = Int(model.size.y)
        textureDescriptor.depth = Int(model.size.z)
        textureDescriptor.pixelFormat = .r16Uint
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        let attributes = try device.makeDefaultLibrary(bundle: .renderKitShadersModule).makeFunction(name: "VoxelVertexShader")!.vertexAttributes!
        let vertexDescriptor = MTLVertexDescriptor(attributes: attributes)
        let vertexSize = vertexDescriptor.layouts[0].stride

        let vertexBuffer = device.makeBuffer(length: maxVertexCount * vertexSize, options: .storageModeShared)!
        vertexBuffer.label = "Voxel Vertices"

        let indexBuffer = device.makeBuffer(length: maxIndexCount * MemoryLayout<Int32>.size, options: .storageModeShared)!

        try timeit("Compute") {
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            texture.label = "Voxels"
            let library = try device.makeDefaultLibrary(bundle: .renderKitShadersModule)
            let commandQueue = device.makeCommandQueue()!
            let commandBuffer = commandQueue.makeCommandBuffer()!

            try Compute(function: library.makeFunction(name: "magicaVoxelsToColorIndexTexture3D")!).compute(commandBuffer: commandBuffer) { encoder, workSize in
                workSize.configure(threadsPerGrid: [model.voxels.count, 1, 1], threadsPerThreadGroup: [1, 1, 1])
                encoder.setBuffer(voxelBuffer, offset: 0, index: VoxelsBindings.voxelsBuffer)
                encoder.setTexture(texture, index: VoxelsBindings.outputTexture)
            }

            // MARK: -

            try Compute(function: library.makeFunction(name: "voxelsToVertices")!).compute(commandBuffer: commandBuffer) { encoder, workSize in
                workSize.configure(threadsPerGrid: [model.voxels.count, 1, 1], threadsPerThreadGroup: [1, 1, 1])
                encoder.setBuffer(voxelBuffer, offset: 0, index: VoxelsBindings.voxelsBuffer)
                encoder.setBuffer(vertexBuffer, offset: 0, index: VoxelsBindings.verticesBuffer)
                encoder.setBuffer(indexBuffer, offset: 0, index: VoxelsBindings.indicesBuffer)
                let voxelSize: SIMD3<Float> = [0.05, 0.05, 0.05]
                withUnsafeBytes(of: voxelSize) { buffer in
                    encoder.setBytes(buffer.baseAddress!, length: buffer.count, index: VoxelsBindings.voxelSizeBuffer)
                }
            }

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        //        vertexBuffer.dump(using: vertexDescriptor)

        let indices = UnsafeBufferPointer<Int32>(start: indexBuffer.contents().assumingMemoryBound(to: Int32.self), count: maxIndexCount)
        let filteredIndices = indices.filter { $0 != -1 }
        let filteredIndicesBuffer = device.makeBuffer(bytesOf: filteredIndices, options: .storageModeShared)!
        filteredIndicesBuffer.label = "Voxel Filter Indices"

        let colorPaletteTextureDescriptor = MTLTextureDescriptor()
        colorPaletteTextureDescriptor.textureType = .type1D
        colorPaletteTextureDescriptor.width = Int(model.colors.count)
        colorPaletteTextureDescriptor.height = 1
        colorPaletteTextureDescriptor.depth = 1
        colorPaletteTextureDescriptor.pixelFormat = .rgba8Unorm
        colorPaletteTextureDescriptor.storageMode = .shared
        colorPaletteTextureDescriptor.usage = .shaderRead
        let colorPaletteTexture = device.makeTexture(descriptor: colorPaletteTextureDescriptor)!

        model.colors.withUnsafeBytes { buffer in
            colorPaletteTexture.replace(region: MTLRegion(origin: .zero, size: [Int(model.colors.count), 1, 1]), mipmapLevel: 0, slice: 0, withBytes: buffer.baseAddress!, bytesPerRow: buffer.count, bytesPerImage: 0)
        }

        self.vertexBuffer = vertexBuffer
        self.indexBuffer = filteredIndicesBuffer
        indexCount = filteredIndices.count
        colorPalette = colorPaletteTexture
    }
}

// MARK: -

public extension MTLRenderCommandEncoder {
    func draw(voxel: VoxelModel) {
        drawIndexedPrimitives(type: .triangle, indexCount: voxel.indexCount, indexType: .uint32, indexBuffer: voxel.indexBuffer, indexBufferOffset: 0)
    }
}
