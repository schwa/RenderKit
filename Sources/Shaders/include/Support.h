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
