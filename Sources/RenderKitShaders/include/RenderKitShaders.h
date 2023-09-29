#pragma once

#ifdef __METAL_VERSION__
#import <simd/simd.h>
#import <metal_stdlib>
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
using namespace metal;
#else
#import <simd/simd.h>
#import <Foundation/Foundation.h>
typedef simd_float2 float2;
typedef simd_float3 float3;
typedef simd_float4 float4;
typedef simd_float3x3 float3x3;
typedef simd_float4x4 float4x4;
#endif

#import "ImmsersiveShadersTypes.h"
#import "VolumeShaders.h"
#import "CommonTypes.h"

#ifdef __METAL_VERSION__
namespace RenderKitShaders {
    constexpr sampler basicSampler(coord::normalized, address::clamp_to_edge, filter::linear);
};
#endif
