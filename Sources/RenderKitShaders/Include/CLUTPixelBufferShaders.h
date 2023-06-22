//
//  Header.h
//
//
//  Created by Jonathan Wight on 7/7/21.
//

#pragma once

#import <simd/simd.h>

// TODO: Rename blitter

#define CLUTPixelBufferVertexShader_Vertices 0
#define CLUTPixelBufferVertexShader_Uniforms 1

#define CLUTPixelBufferFragmentShader_LookupTexture 2
#define CLUTPixelBufferFragmentShader_ColorMapTexture 3

struct CLUTPixelBufferUniforms {
    simd_float3x4 transform;
};
