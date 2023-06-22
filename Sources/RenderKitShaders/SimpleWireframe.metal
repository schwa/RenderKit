//
//  SimpleWireframeView.metal
//  GraphicsDemos_OSX
//
//  Created by Jonathan Wight on 2/20/20.
//  Copyright © 2020 schwa.io. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "Include/SimpleWireframe.h"

using namespace metal;

// NEW
struct Fragment {
    float4 position [[position]];
    float4 color;
};

vertex Fragment simpleWireframeVertexShader(
    uint vertexID [[vertex_id]],
    constant packed_float4 *vertices [[buffer(SimpleWireframeVertexShader_Vertices)]],
    constant UniformsX &uniforms [[buffer(SimpleWireframeVertexShader_Uniforms)]])
{
    Fragment out;

    const float4 position = vertices[vertexID];
    out.position = position * uniforms.modelViewProjectionTransform;
    out.color = float4(1, 0, 0, 1);
    return out;
}

fragment vector_float4 simpleWireframeFragmentShader(
    Fragment input [[stage_in]],
    constant UniformsX &uniforms [[buffer(SimpleWireframeFragmentShader_Uniforms)]]
    )
{
    return input.color;
}
