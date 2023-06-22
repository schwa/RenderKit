//
//  Skydome.metal
//  GraphicsDemos_OSX
//
//  Created by Jonathan Wight on 2/19/20.
//  Copyright © 2020 schwa.io. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

#include "Include/RenderKit.h"
#include "Include/Skydome.h"

using namespace metal;

struct SkydomeVertex {
    packed_float3 position; // offset: 0
    packed_float3 normal; // offset: 12
    packed_float2 textureCoordinate; // offset: 24
};

struct Fragment {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex Fragment SkydomeVertexShader(
    uint vertexID [[vertex_id]],
    constant SkydomeVertex *vertices [[buffer(SkydomeVertexShader_Vertices)]],
    constant UniformsX &uniforms [[buffer(SkydomeVertexShader_Uniforms)]])
{
    Fragment out;

    const float4 position = vector_float4(vertices[vertexID].position, 1);
    out.position = position * uniforms.modelViewProjectionTransform;
    out.textureCoordinate = vertices[vertexID].textureCoordinate;
    return out;
}

fragment vector_float4 SkydomeFragmentShader(
    Fragment input [[stage_in]],
    constant UniformsX &uniforms [[buffer(SkydomeFragmentShader_Uniforms)]],
    texture2d<float> baseTexture [[texture(SkydomeFramgentShader_BaseTexture)]]
    )
{
    constexpr sampler s1(coord::normalized, address::clamp_to_edge, filter::nearest);
    float3 baseColor = baseTexture.sample(s1, input.textureCoordinate).rgb;
    return float4(baseColor, 1);
}
