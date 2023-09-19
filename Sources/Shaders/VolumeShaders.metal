#import <metal_stdlib>
#import <simd/simd.h>
#import <metal_geometric>

#import "include/Shaders.h"
#import "include/VolumeShaders.h"

using namespace metal;

float4 transferFunction(ushort f, float m) {
    return float4(1, 1, 1, float(f) / 3272 * m);
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
    constant VolumeTransforms &transforms [[buffer(2)]],
    constant VolumeInstance *instances [[buffer(3)]],
    ushort instance_id [[instance_id]]
    )
{
    const VolumeInstance instance = instances[instance_id];
    const float4 offset = float4(0, 0, instance.offsetZ, 1.0);
    const float3 textureCoordinate = float3(in.textureCoordinate, instance.textureZ);

    // Kill rotation from modelView matrix.
    // TODO: This also kills scale.
    float4x4 modelViewMatrix = transforms.modelViewMatrix;
    // TODO: Hack the scale in here until i can bothered to fix this.
    modelViewMatrix[0][0] = 2.0;
    modelViewMatrix[0][1] = 0.0;
    modelViewMatrix[0][2] = 0.0;
    modelViewMatrix[1][0] = 0.0;
    modelViewMatrix[1][1] = 2.0;
    modelViewMatrix[1][2] = 0.0;
    modelViewMatrix[2][0] = 0.0;
    modelViewMatrix[2][1] = 0.0;
    modelViewMatrix[2][2] = 2.0;
    
    float4x4 textureMatrix = transforms.textureMatrix;
    
    float3 rotatedTextureCoordinate = (textureMatrix * float4(textureCoordinate, 1.0)).xyz;
    
    
    const float4 modelVertex = modelViewMatrix * float4(in.position + offset.xyz, 1.0);
    const float4 clipSpace = cameraUniforms.projectionMatrix * modelVertex;
    return {
        .position = clipSpace,
        .textureCoordinate = rotatedTextureCoordinate,
    };
}

// MARK: -

[[fragment]]
float4 volumeFragmentShader(
    FragmentIn in [[stage_in]],
    texture3d<unsigned short, access::sample> texture [[texture(0)]],
    texture2d<half, access::sample> transferFunctionTexture [[texture(1)]],
    sampler sampler [[sampler(0)]],
    constant VolumeFragmentUniforms &uniforms [[buffer(0)]]
    )
{
    if (
        in.textureCoordinate.x < 0 || in.textureCoordinate.x > 1.0
        || in.textureCoordinate.y < 0 || in.textureCoordinate.y > 1.0
        || in.textureCoordinate.z < 0 || in.textureCoordinate.z > 1.0
        ) {
        discard_fragment();
    }
    const unsigned short textureColor = texture.sample(sampler, in.textureCoordinate).r;
    auto color = transferFunction(textureColor, 1.0 * 10 / float(uniforms.instanceCount));
    return color;

    // TODO: commented out transferFunctionTexture for now
//    const float value = float(texture.sample(sampler, in.textureCoordinate).r / 3272); // TODO: Magic number
//    auto alpha = transferFunctionTexture.sample(sampler, float2(value, 0) ).r;
//    return float4(1, 1, 1, float(alpha) / float(uniforms.instanceCount));
}

