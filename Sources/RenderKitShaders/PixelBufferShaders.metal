
#include <metal_stdlib>
#include <simd/simd.h>

#include "Include/RenderKit.h"
#include "Include/PixelBufferShaders.h"

using namespace metal;

struct Fragment {
    vector_float4 position [[position]];
    vector_float2 textureCoords;
};

vertex Fragment pixelBufferVertexShader(
    uint vertexID [[vertex_id]],
    constant VertexBasicX *vertices [[buffer(PixelBufferVertexShader_Vertices)]],
    constant PixelBufferUniforms &uniforms [[buffer(PixelBufferVertexShader_Uniforms)]])
{
    Fragment out;
    out.position = vector_float4(vector_float4(vertices[vertexID].position, 0, 1) * uniforms.transform, 1);
    out.textureCoords = vertices[vertexID].textureCoords;
    return out;
}

fragment vector_float4 pixelBufferFragmentShader(
    Fragment in [[stage_in]],
    texture2d<float> pixelBufferTexture [[texture(PixelBufferFramgentShader_Texture)]])
{
    constexpr sampler s1(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 color = pixelBufferTexture.sample(s1, in.textureCoords);
    return color;
}

