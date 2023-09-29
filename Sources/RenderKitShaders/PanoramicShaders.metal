#import <metal_stdlib>
#import <simd/simd.h>
#import <metal_geometric>

#import "include/Shaders.h"

using namespace metal;

typedef SimpleVertex Vertex;

struct Fragment {
    float4 position [[position]]; // in projection space
    float2 textureCoordinate;
};

// MARK: -

[[vertex]]
Fragment panoramicVertexShader(
    Vertex in [[stage_in]],
    constant CameraUniforms &cameraUniforms [[buffer(1)]],
    constant float4x4 &modelViewMatrix [[buffer(2)]]
)
{
    const float4 modelVertex = modelViewMatrix * float4(in.position, 1.0);
//    const float4 modelVertex = float4(in.position, 1.0);
    return {
        .position = cameraUniforms.projectionMatrix * modelVertex,
        .textureCoordinate = in.textureCoordinate
    };
}

constant size_t texture_count [[function_constant(0)]];

[[fragment]]
vector_float4 panoramicFragmentShader(
    Fragment in [[stage_in]],
    constant ushort2 &gridSize[[buffer(0)]],
    array<texture2d<float, access::sample>, 12> tiles [[texture(0)]]
    )
{
    constexpr sampler basicSampler(coord::normalized, address::clamp_to_edge, filter::linear);

    const float2 denormalizedTextureCoordinate = in.textureCoordinate * float2(gridSize);
    const ushort textureIndex = clamp(ushort(denormalizedTextureCoordinate.y) * gridSize.x + ushort(denormalizedTextureCoordinate.x), 0, ushort(tiles.size()) - 1);
    const float2 textureCoordinate = denormalizedTextureCoordinate - floor(denormalizedTextureCoordinate);
    const float d = 1.0 / float(tiles[textureIndex].get_width());
    if (textureCoordinate.x <= d || textureCoordinate.x >= 1 - d || textureCoordinate.y < d || textureCoordinate.y > 1 - d) {
        return float4(1, 0, 0, 1);
    }


    const auto color = tiles[textureIndex].sample(basicSampler, textureCoordinate);
    return color;
}
