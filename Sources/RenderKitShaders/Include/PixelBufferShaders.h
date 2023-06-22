//
//  Header.h
//  
//
//  Created by Jonathan Wight on 7/7/21.
//

#pragma once

#import <simd/simd.h>

// TODO: Rename blitter

#define PixelBufferVertexShader_Vertices 0
#define PixelBufferVertexShader_Uniforms 1

#define PixelBufferFramgentShader_Texture 2

//struct VertexBasicX {
//    simd_float2 position;
//    simd_float2 textureCoords;
//};

struct PixelBufferUniforms {
    simd_float3x4 transform;
};
