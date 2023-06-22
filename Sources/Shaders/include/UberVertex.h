//
//  UberVertex.h
//  RenderKitDemo
//
//  Created by Jonathan Wight on 2/2/22.
//

#pragma once

//#ifdef __METAL_VERSION__
//#include <metal_stdlib>
//#endif

#import <simd/simd.h>

struct Vertex {
#ifdef __METAL_VERSION__
    float3 position [[attribute(XX)]];
    float3 normal [[attribute(XX)]];
    float4 tangent [[attribute(XX)]];
    float2 textureCoordinate0 [[attribute(XX)]];

    float4 color0 [[attribute(XX)]];
    float4 joints0 [[attribute(XX)]];
    float4 weights0 [[attribute(XX)]];

    // bitangent
#else
#endif
};

