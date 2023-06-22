
#include <metal_stdlib>
#include <simd/simd.h>

#include "Include/RenderKit.h"
#include "Include/CLUTPixelBufferShaders.h"

using namespace metal;

struct Fragment {
    vector_float4 position [[position]];
    vector_float2 textureCoords;
};

vertex Fragment clutPixelBufferVertexShader(uint vertexID [[vertex_id]],
                                   constant VertexBasicX *vertices [[buffer(CLUTPixelBufferVertexShader_Vertices)]],
                                   constant CLUTPixelBufferUniforms &uniforms [[buffer(CLUTPixelBufferVertexShader_Uniforms)]]) {
    Fragment out;
    out.position = vector_float4(vector_float4(vertices[vertexID].position, 0, 1) * uniforms.transform, 1);


    out.textureCoords = vertices[vertexID].textureCoords;
    return out;
}

// TODO: colorMapTexture make colorMapTexture a texture1d
fragment vector_float4 clutPixelBufferFragmentShader(Fragment in [[stage_in]],
                               texture2d<ushort> lookupTexture [[texture(CLUTPixelBufferFragmentShader_LookupTexture)]],
                               texture2d<float> colorMapTexture [[texture(CLUTPixelBufferFragmentShader_ColorMapTexture)]]) {

    constexpr sampler s1(coord::normalized, address::clamp_to_edge, filter::nearest);
    ushort value = lookupTexture.sample(s1, in.textureCoords).r;
    // Just read directly from the color map
    return colorMapTexture.read(ushort2(value, 0));
}

