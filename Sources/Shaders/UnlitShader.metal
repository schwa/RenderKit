#include <metal_stdlib>
#include <simd/simd.h>
#include "include/Shaders.h"

using namespace metal;

struct Fragment
{
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex Fragment FlatVertexShader(
    Vertex in [[stage_in]],
    constant Transforms &transforms [[buffer(CommonBindings_TransformsBuffer)]],
    constant float3 &offset [[buffer(UnlitShaderBindings_OffsetsBuffer)]]
    )
{
    Fragment out;
    out.position = transforms.projection * transforms.modelView * float4(in.position, 1.0);
    out.position.xyz += offset;
    out.textureCoordinate = in.textureCoordinate;
    return out;
}

fragment float4 FlatFragmentShader(
    Fragment in [[stage_in]],
    texture2d<float> texture [[texture(UnlitShaderBindings_BaseColorTexture)]],
    sampler sampler[[sampler(UnlitShaderBindings_BaseColorSampler)]])
{
    return texture.sample(sampler, in.textureCoordinate);
}

fragment float4 FlatFragmentShader_uint(
                                          Fragment in [[stage_in]],
                                          texture2d<uint> texture [[texture(UnlitShaderBindings_BaseColorTexture)]],
                                          sampler sampler[[sampler(UnlitShaderBindings_BaseColorSampler)]])
{
    uint4 source = texture.sample(sampler, in.textureCoordinate);



    return float4(source);
}
