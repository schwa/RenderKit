#import <metal_stdlib>
#import <simd/simd.h>
#import <metal_geometric>

#import "include/Shaders.h"

using namespace metal;


struct Fragment {
    float4 position [[position]]; // in projection space
    float3 modelPosition;
    float3 interpolatedNormal[[flat]];
    float2 textureCoordinate;
    float4 color;
};

// MARK: -

[[vertex]]
Fragment panoramicVertexShader(Vertex in [[stage_in]], constant CameraUniforms &cameraUniforms [[buffer(1)]], constant ModelUniforms &modelUniforms [[buffer(2)]])
{
    const float4 modelVertex = modelUniforms.modelViewMatrix * float4(in.position, 1.0);
    return {
        .position = cameraUniforms.projectionMatrix * modelVertex,
        .modelPosition = float3(modelVertex) / modelVertex.w,
        .interpolatedNormal = modelUniforms.modelNormalMatrix * in.normal,
        .textureCoordinate = in.textureCoordinate,
        .color = modelUniforms.color
    };
}

[[fragment]]
vector_float4 panoramicFragmentShader(
    Fragment in [[stage_in]],
    constant LightUniforms &lightUniforms [[buffer(3)]],
    array<texture2d<float, access::sample>, 3> tiles [[texture(0)]]
    )
{
    constexpr sampler basicSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    const auto color = tiles[0].sample(basicSampler, in.textureCoordinate);
    return color;
}
