//
//  Header.h
//  
//
//  Created by Jonathan Wight on 7/8/21.
//

#import <simd/simd.h>
#import "RenderKit.h"

typedef NS_ENUM(NSInteger, SimpleWireframeVertexShader)
{
    SimpleWireframeVertexShader_Vertices = 0,
    SimpleWireframeVertexShader_Uniforms  = 1,
};

typedef NS_ENUM(NSInteger, SimpleWireframeFragmentShader)
{
    SimpleWireframeFragmentShader_Uniforms = 0,
};
