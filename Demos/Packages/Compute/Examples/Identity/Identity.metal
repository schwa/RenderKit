#include <metal_stdlib>

using namespace metal;

kernel void identity(texture2d<half, access::read> inTexture [[texture(0)]],
                   texture2d<half, access::write> outTexture [[texture(1)]],
                   uint2 gid [[thread_position_in_grid]])
{
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    auto color = inTexture.read(gid);
    outTexture.write(color, gid);
}
