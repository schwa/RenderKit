//
//  Testbed.metal
//  GraphicsDemos_OSX
//
//  Created by Jonathan Wight on 12/1/19.
//  Copyright © 2019 schwa.io. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

#include "Include/RenderKit.h"

using namespace metal;

// buffer: 0
struct Vertex {
    packed_float3 position; // offset: 0
    packed_float3 normal; // offset: 12
    packed_float2 textureCoordinate; // offset: 24
};

struct Uniforms {
    simd_float4x4 modelViewProjectionTransform;
    simd_float4x4 modelViewTransform; // NEW
    simd_float3x3 normalTransform; // NEW
};

// NEW
struct Fragment {
    float4 position [[position]];
    float2 textureCoordinate;
    float3 eye;
    float3 normal;
};

struct Light {
    packed_float3 direction;
    packed_float3 ambientColor;
    packed_float3 diffuseColor;
    packed_float3 specularColor;
};

//struct Material {
//
//    union {
//        packed_float3 specularColor;
//        texture2d<float> specularTexture [[texture(99)]];
//    };
//
//    packed_float3 ambientColor;
//    packed_float3 diffuseColor;
//    float specularPower;
//};

// MARK: -

vertex Fragment SphereVertexShader(
    uint vertexID [[vertex_id]],
    constant Vertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    Fragment out;

    const float4 position = vector_float4(vertices[vertexID].position, 1);
    out.position = position * uniforms.modelViewProjectionTransform;
    out.textureCoordinate = vertices[vertexID].textureCoordinate;

    out.eye = -(uniforms.modelViewTransform * position).xyz;
    out.normal = uniforms.normalTransform * vertices[vertexID].normal.xyz;

    return out;
}

fragment vector_float4 SphereFragmentShader(
    Fragment input [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]],
    texture2d<float> diffuseTexture [[texture(2)]],
    texture2d<float> ambientTexture [[texture(3)]],
    texture2d<float> specularTexture [[texture(4)]]
    )
{
    constexpr sampler s1(coord::normalized, address::clamp_to_edge, filter::nearest);
    float3 diffuseColor = diffuseTexture.sample(s1, input.textureCoordinate).rgb;
    float3 ambientColor = ambientTexture.sample(s1, input.textureCoordinate).rgb;
    float3 specularColor = specularTexture.sample(s1, input.textureCoordinate).rgb;
    float specularPower = 100;

    Light light = {
        .direction = float3(1, 0, 1),
        .ambientColor = float3(0, 0, 0),
        .diffuseColor = float3(1, 1, 1),
        .specularColor = float3(1, 1, 1),
    };

    float3 ambientTerm = light.ambientColor * ambientColor;
    float3 normal = normalize(input.normal);
    float diffuseIntensity = saturate(dot(normal, light.direction));
    float3 diffuseTerm = light.diffuseColor * diffuseColor * diffuseIntensity;
    float3 specularTerm(0);
    if (diffuseIntensity > 0) {
        float3 eyeDirection = normalize(input.eye);
        float3 halfway = normalize(light.direction + eyeDirection);
        float specularFactor = pow(saturate(dot(normal, halfway)), specularPower);
        specularTerm = light.specularColor * specularColor * specularFactor;
    }
    return float4(ambientTerm + diffuseTerm + specularTerm, 1);
}
