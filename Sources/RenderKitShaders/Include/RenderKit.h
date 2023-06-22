//
//  MetalTypes.h
//  GraphicsDemos
//
//  Created by Jonathan Wight on 10/13/17.
//  Copyright © 2017 schwa.io. All rights reserved.
//

#pragma once

#import <simd/simd.h>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif


// TODO: Rename to Vertex2D or something??? (research what ogl users call them?)
struct VertexBasicX {
    packed_float2 position;
    packed_float2 textureCoords;
};

// MARK: -

struct UniformsX {
    simd_float4x4 modelViewProjectionTransform;
    simd_float4x4 modelViewTransform; // NEW
    simd_float4x4 normalTransform; // NEW
};

