//
//  ARShader.metal
//  GraphicsDemos_iOS
//
//  Created by Jonathan Wight on 3/28/20.
//  Copyright © 2020 schwa.io. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

/*
TODO

    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        var texture: CVMetalTexture!
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        if status != kCVReturnSuccess {
            fatal(error: GeneralError.unhandledSystemFailure)
        }
        return CVMetalTextureGetTexture(texture)!
    }

 */

struct PixelBufferYCbCrVertex {
    vector_float2 position;
    vector_float2 textureCoords;
};

struct PixelBufferYCbCrUniforms {
    simd_float3x4 transform;
};

struct Fragment {
    vector_float4 position [[position]];
    vector_float2 textureCoords;
};

// MARK: -

vertex Fragment PixelBufferYCbCrVertexShader(
    uint vertexID [[vertex_id]],
    constant PixelBufferYCbCrVertex *vertices [[buffer(0)]],
    constant PixelBufferYCbCrUniforms &uniforms [[buffer(1)]])
{
    Fragment out;
    out.position = vector_float4(vector_float4(vertices[vertexID].position, 0, 1) * uniforms.transform, 1);
    out.textureCoords = vertices[vertexID].textureCoords;
    return out;
}

// MARK: -


// Captured image fragment function
fragment float4 PixelBufferYCbCrFragmentShader(
    Fragment in [[stage_in]],
    texture2d<float, access::sample> textureY [[ texture(0) ]],
    texture2d<float, access::sample> textureCbCr [[ texture(1) ]])
{
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(textureY.sample(colorSampler, in.textureCoords).r,
    textureCbCr.sample(colorSampler, in.textureCoords).rg, 1.0);

    // Return converted RGB color
    return ycbcrToRGBTransform * ycbcr;
}
