#pragma once

#import <simd/simd.h>
#import "Support.h"

struct Vertex {
#ifdef __METAL_VERSION__
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 textureCoordinate [[attribute(2)]];
#else
    float3 position;
    float3 normal;
    float2 textureCoordinate;
#endif
};

struct ModelUniforms { // Rename to ModelState?
    simd_float4x4 modelViewMatrix; // model space -> camera space
    simd_float3x3 modelNormalMatrix; // model space - used for non-uniform scaled normal transformation. See https://www.youtube.com/watch?v=esC1HnyD9Bk&list=PLplnkTzzqsZS3R5DjmCQsqupu43oS9CFN
    simd_float4 color;
};

struct CameraUniforms {
    simd_float4x4 projectionMatrix;
};

struct LightUniforms {
    // Per diffuse light
    float3 lightPosition;
    float3 lightColor;
    float lightPower;
    // Per environment
    float3 ambientLightColor;
};
