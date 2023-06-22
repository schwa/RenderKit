#include "include/Shaders.h"

using namespace metal;

struct Fragment
{
    float4 position [[position]];
    float2 textureCoordinate;
    float3 modelPosition;
    float3 normal;
    float3 interpolatedNormal;
};

vertex Fragment DebugVisualizerVertexShader(
    Vertex in [[stage_in]],
    constant Transforms &transforms [[buffer(CommonBindings_TransformsBuffer)]],
    constant float3 &offset [[buffer(UnlitShaderBindings_OffsetsBuffer)]] // TODO: Use own binding
    )
{
    Fragment out;
    float4 modelVertex = transforms.modelView * float4(in.position, 1.0);
    out.position = transforms.projection * modelVertex + float4(offset, 0);
    out.textureCoordinate = in.textureCoordinate;
    out.modelPosition = float3(modelVertex) / modelVertex.w;
    out.normal = in.normal;
    out.interpolatedNormal = transforms.modelNormal * in.normal;
    return out;
}

fragment float4 DebugVisualizerFragmentShader(
    Fragment in [[stage_in]],
    constant int &mode[[buffer(DebugShaderBindings_ModeBuffer)]])
{
    switch(mode) {
        case 0: // Constant white
            return float4(1, 1, 1, 1);
        case 1: // Clipspace position
            return float4(normalize(in.position.xyz), 1);
        case 2: // Texture coordinate
            return float4(normalize(in.textureCoordinate), 0, 1);
        case 3: // Model normal
            return float4(in.normal, 1);
        case 4: // Normal interpolated
            return float4(in.interpolatedNormal, 1);
        default:
            return float4(1, 1, 0, 1);
    }

}
