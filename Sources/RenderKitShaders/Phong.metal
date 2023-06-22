
#include <metal_stdlib>
#include <simd/simd.h>

#include "Include/RenderKit.h"
#include "Include/Phong.h"

using namespace metal;

// From Metal By Example


struct Fragment {
    vector_float4 position [[position]];
    vector_float3 eye;
    vector_float3 normal;
};


//struct AmbientLight {
//    float3 color;
//};

vertex Fragment phongVertexShader(uint vertexID [[vertex_id]],
                                  constant PhongVertex *vertices [[buffer(PhongVertexShader_Vertices)]],
                                  constant UniformsX &uniforms [[buffer(PhongVertexShader_Uniforms)]])
{
    Fragment out;
    auto position = vector_float4(vertices[vertexID].position, 1.0);
    out.position =  position * uniforms.modelViewProjectionTransform;
    out.eye = -(uniforms.modelViewTransform * position).xyz;
    auto normal = vector_float4(vertices[vertexID].normal, 1.0);
    out.normal = (uniforms.normalTransform * normal).xyz;
    return out;
}

fragment vector_float4 phongFragmentShader(Fragment in [[stage_in]],
                                           constant PhongMaterial &material [[buffer(PhongFragmentShader_Material)]],
                                           constant PhongDirectionalLight &light [[buffer(PhongFragmentShader_Light)]])
{
    const float3 ambientTerm = light.ambientColor * material.ambientColor;
    const float3 normal = normalize(in.normal);
    const float diffuseIntensity = saturate(dot(normal, light.direction));
    const float3 diffuseTerm = light.diffuseColor * material.diffuseColor * diffuseIntensity;
    float3 specularTerm = 0;
    if (diffuseIntensity > 0) {
        const float3 eyeDirection = normalize(in.eye);
        const float3 halfway = normalize(light.direction + eyeDirection);
        const float specularFactor = pow(saturate(dot(normal, halfway)), material.specularPower);
        specularTerm = light.specularColor * material.specularColor * specularFactor;
    }
    return float4(ambientTerm + diffuseTerm + specularTerm, 1);

}

