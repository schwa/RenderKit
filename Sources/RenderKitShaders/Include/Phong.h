//
//  Header.h
//  
//
//  Created by Jonathan Wight on 7/7/21.
//

#pragma once

#import <simd/simd.h>
#import "RenderKit.h"

typedef NS_ENUM(NSInteger, PhongVertexShader)
{
    PhongVertexShader_Vertices = 0,
    PhongVertexShader_Uniforms  = 1,
};

typedef NS_ENUM(NSInteger, PhongFragmentShader)
{
    PhongFragmentShader_Material = 0,
    PhongFragmentShader_Light  = 1,
};

struct PhongVertex {
#ifdef __METAL_VERSION__
    packed_float3 position; // offset: 0
    packed_float3 normal; // offset: 12
    packed_float2 textureCoordinate; // offset: 24
#endif
};

struct PhongMaterial {
    simd_float3 ambientColor;
    simd_float3 diffuseColor;
    simd_float3 specularColor;
    float specularPower;
};

struct PhongDirectionalLight {
    simd_float3 direction;
    simd_float3 ambientColor; // TODO: Break out into own light object AmbientLight
    simd_float3 diffuseColor;
    simd_float3 specularColor;
};
