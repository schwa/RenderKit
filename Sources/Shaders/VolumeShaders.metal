#import <metal_stdlib>
#import <simd/simd.h>
#import <metal_geometric>

#import "include/Shaders.h"
#import "include/VolumeShaders.h"

using namespace metal;

struct Fragment {
    float4 position [[position]]; // in projection space
    float3 modelPosition;
    float3 interpolatedNormal[[flat]];
    float3 textureCoordinate;
};

// MARK: -

[[vertex]]
Fragment volumeVertexShader(
    Vertex in [[stage_in]],
    constant CameraUniforms &cameraUniforms [[buffer(1)]],
    constant ModelUniforms &modelUniforms [[buffer(2)]],
    constant VolumeInstance *instances [[buffer(3)]],
    ushort instance_id [[instance_id]]
    )
{
    const float4 modelVertex = modelUniforms.modelViewMatrix * float4(in.position, 1.0);
    
    const auto instance = instances[instance_id];
    
    
    return {
        .position = cameraUniforms.projectionMatrix * modelVertex,
        .modelPosition = float3(modelVertex) / modelVertex.w,
        .interpolatedNormal = modelUniforms.modelNormalMatrix * in.normal,
        .textureCoordinate = float3(in.textureCoordinate, instance.textureZ),
    };
}

[[fragment]]
vector_float4 volumeFragmentShader(
    Fragment in [[stage_in]],
    texture3d<unsigned short, access::sample> texture [[texture(0)]],
    sampler sampler [[sampler(0)]]
    )
{
    const auto textureColor = texture.sample(sampler, in.textureCoordinate);
    
    
    
    return float4(float(textureColor.r) / 200, 0.1, 0.1, 1);
}
