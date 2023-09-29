#import "include/RenderKitShaders.h"

typedef SimpleVertex Vertex;

struct Fragment {
    float4 position [[position]]; // in projection space
    float3 modelPosition;
    float3 interpolatedNormal[[flat]];
    float2 textureCoordinate;
    float4 color;
};

// MARK: -

[[vertex]]
Fragment flatShaderVertexShader(
    Vertex in [[stage_in]],
    ushort instance_id[[instance_id]],
    constant CameraUniforms &cameraUniforms [[buffer(1)]],
    constant ModelUniforms *instancedModelUniforms [[buffer(2)]]
    )
{
    const ModelUniforms modelUniforms = instancedModelUniforms[instance_id];
    const float4 modelVertex = modelUniforms.modelViewMatrix * float4(in.position, 1.0);
    return {
        .position = cameraUniforms.projectionMatrix * modelVertex,
        .modelPosition = float3(modelVertex) / modelVertex.w,
        .interpolatedNormal = modelUniforms.modelNormalMatrix * in.normal,
        .textureCoordinate = in.textureCoordinate,
        .color = modelUniforms.color
    };
}

[[fragment]]
vector_float4 flatShaderFragmentShader(Fragment in [[stage_in]], constant LightUniforms &lightUniforms [[buffer(3)]])
{
    const auto diffuseMaterialColor = in.color.rgb;
    const auto ambientMaterialColor= in.color.rgb;

    // Compute diffuse color
    const auto normal = normalize(in.interpolatedNormal);
    const auto lightDirection = lightUniforms.lightPosition - in.modelPosition;
    const auto lambertian = max(dot(lightDirection, normal), 0.0);
    const auto lightDistanceSquared = length_squared(lightDirection);
    const auto diffuseColor = diffuseMaterialColor * lambertian * lightUniforms.lightColor * lightUniforms.lightPower / lightDistanceSquared;

    // Compute ambient color
    const auto ambientColor = lightUniforms.ambientLightColor * ambientMaterialColor;

    return float4(diffuseColor + ambientColor, 1.0);
}
