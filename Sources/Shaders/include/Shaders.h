#pragma once

#import <simd/simd.h>

#ifdef __METAL_VERSION__
#include <metal_stdlib>
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
typedef simd_float2 float2;
typedef simd_float3 float3;
typedef simd_float4 float4;
#endif

#import "Support.h"
#import "FlatShader.h"
#import "VolumeShaders.h"
#import "ImmsersiveShadersTypes.h"

#ifdef __METAL_VERSION__
struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 textureCoordinate [[attribute(2)]];
};
#else
#pragma pack(push, 1)
struct Vertex {
    float3 position;
    float3 normal;
    float2 textureCoordinate;
};
#pragma pack(pop)
#endif

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
