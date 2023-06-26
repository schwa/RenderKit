
#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ShaderToyVertex {
    vector_float3 position [[attribute(0)]];
    vector_float3 normal [[attribute(1)]];
    vector_float2 textureCoords [[attribute(2)]];
};

struct ShaderToyVertexUniforms {
    simd_float3x4 transform;
};

struct ShaderToyFragmentUniforms {
    float time;
    vector_float2 scale;
};

struct Fragment {
    vector_float4 position [[position]];
};

// MARK: -

enum ShaderToyID {
    kShaderToyID_Vertices = 0,
    kShaderToyID_VertexShaderUniforms = 1,
    kShaderToyID_FragmentShaderUniforms = 2,
};

// MARK: -

[[vertex]]
Fragment shaderToyVertexShader(ShaderToyVertex vertexIn [[stage_in]], constant ShaderToyVertexUniforms &uniforms [[buffer(kShaderToyID_VertexShaderUniforms)]])
{
    return { .position = vector_float4(vector_float4(vertexIn.position, 1) * uniforms.transform, 1) };
}

constant bool floorXY [[function_constant(0)]];

[[fragment]]
vector_float4 shaderToyFragmentShader(Fragment fragmentIn [[stage_in]], constant ShaderToyFragmentUniforms &uniforms [[buffer(kShaderToyID_FragmentShaderUniforms)]])
{
    vector_float2 xy = fragmentIn.position.xy * uniforms.scale;
    if (floorXY) {
        xy = floor(xy);
    }

    const float x = xy.x;
    const float y = xy.y;

    const float step = uniforms.time;

    const float xs = sin(step / 100.0) * 20.0;
    const float ys = cos(step / 100.0) * 20.0;
    const float scale = ((sin(step / 60.0) + 1.0) / 5.0) + 0.2;
    const float r = sin((x + xs) * scale) + cos((y + xs) * scale);
    const float g = sin((x + xs) * scale) + cos((y + ys) * scale);
    const float b = sin((x + ys) * scale) + cos((y + ys) * scale);

    return vector_float4(r, g, b, 1.0);
}

