#pragma once

#ifdef __METAL_VERSION__
#import "MetalSupport.h"
#else
#import <simd/simd.h>
#import <Foundation/Foundation.h>
typedef simd_float2 float2;
typedef simd_float3 float3;
typedef simd_float4 float4;
typedef simd_float3x3 float3x3;
typedef simd_float4x4 float4x4;
#endif

#import "CommonTypes.h"

#import "PanoramicShaders.h"
#import "VolumeShaders.h"
