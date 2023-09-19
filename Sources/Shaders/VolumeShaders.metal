#import <metal_stdlib>
#import <simd/simd.h>
#import <metal_geometric>

#import "include/Shaders.h"
#import "include/VolumeShaders.h"

using namespace metal;

float4 transferFunction(ushort f, float m) {
    return float4(s, 1, 1, float(f) / 3272 * m);
}

struct VertexOut {
    float4 position [[position]]; // in projection space
    float3 textureCoordinate;
};
typedef VertexOut FragmentIn;

// MARK: -

[[vertex]]
VertexOut volumeVertexShader(
    Vertex in [[stage_in]],
    constant CameraUniforms &cameraUniforms [[buffer(1)]],
    constant ModelUniforms &modelUniforms [[buffer(2)]],
    constant VolumeInstance *instances [[buffer(3)]],
    ushort instance_id [[instance_id]]
    )
{
    const VolumeInstance instance = instances[instance_id];
    const float4 offset = float4(0, 0, instance.offsetZ, 1.0);
    const float4 modelVertex = modelUniforms.modelViewMatrix * float4(in.position + offset.xyz, 1.0);
    const float4 clipSpace = cameraUniforms.projectionMatrix * modelVertex;
    return {
        .position = clipSpace,
        .textureCoordinate = float3(in.textureCoordinate, instance.textureZ),
    };
}

[[fragment]]
float4 volumeFragmentShader(
    FragmentIn in [[stage_in]],
    texture3d<unsigned short, access::sample> texture [[texture(0)]],
    sampler sampler [[sampler(0)]],
    constant TransferFunctionParameters &transferFunctionParameters [[buffer(0)]]
    )
{
    const float4 badColor = float4(0, 0.5, 0.5, 1);
    const unsigned short textureColor = texture.sample(sampler, in.textureCoordinate).r;
    
    const float w = 0.0125;
    if (
        in.textureCoordinate.x <= w && in.textureCoordinate.y <= w
        || in.textureCoordinate.x <= w && in.textureCoordinate.z <= w
        || in.textureCoordinate.y <= w && in.textureCoordinate.z <= w
        || in.textureCoordinate.x >= 1 - w && in.textureCoordinate.y >= 1 - w
        || in.textureCoordinate.x >= 1 - w && in.textureCoordinate.z >= 1 - w
        || in.textureCoordinate.y >= 1 - w && in.textureCoordinate.z >= 1 - w
        ) {
        //discard_fragment();
        return badColor;
    }

    auto color = transferFunction(textureColor, transferFunctionParameters.m);
//    if (in.textureCoordinate.z < 0.1) {
//        color *= float4(0, 1, 0, 1);
//    }
    
    return color;
}

