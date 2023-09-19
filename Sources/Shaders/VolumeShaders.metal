#import <metal_stdlib>
#import <simd/simd.h>
#import <metal_geometric>

#import "include/Shaders.h"
#import "include/VolumeShaders.h"

using namespace metal;

float4 transferFunction(ushort f);

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
    const float4 modelVertex = modelUniforms.modelViewMatrix * float4(in.position, 1.0);
    const float4 clipSpace = cameraUniforms.projectionMatrix * modelVertex;
    const float4 clipSpaceOffset = float4(0, 0, instance.offsetZ, 1.0);
    return {
        .position = clipSpace + clipSpaceOffset,
        .textureCoordinate = float3(in.textureCoordinate, instance.textureZ),
    };
}

[[fragment]]
float4 volumeFragmentShader(
    FragmentIn in [[stage_in]],
    texture3d<unsigned short, access::sample> texture [[texture(0)]],
    sampler sampler [[sampler(0)]]
    )
{
//    return float4(1, 0, 0, 1.0 - in.textureCoordinate.z);

    const float4 badColor = float4(1, 0, 1, 0.25);
    const unsigned short textureColor = texture.sample(sampler, in.textureCoordinate).r;
    
    if (in.textureCoordinate.x < 0.0 || in.textureCoordinate.y < 0.0) {
        //discard_fragment();
        return badColor;
    }
    else if (in.textureCoordinate.x > 1.0 || in.textureCoordinate.y > 1.0) {
        return badColor;
    }
    else if (in.textureCoordinate.x == 0.5 || in.textureCoordinate.y == 0.5) {
        return badColor;
    }

    return transferFunction(textureColor);
}

float4 transferFunction(ushort f) {
    return float4(1, 0.1, 0.1, float(f) / 3272 * 10);
}
