#include <metal_stdlib>

using namespace metal;

constant float3 kRec709Luma = float3(0.2126, 0.7152, 0.0722);

kernel void grayscaleKernel(texture2d<float, access::read>  inTexture  [[texture(0)]],
                texture2d<float, access::write> outTexture [[texture(1)]],
                uint2                          gid        [[thread_position_in_grid]]) {
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }

    float4 inColor  = inTexture.read(gid);
    float  gray     = dot(inColor.rgb, kRec709Luma);
    outTexture.write(float4(gray, gray, gray, 1.0), gid);
}
