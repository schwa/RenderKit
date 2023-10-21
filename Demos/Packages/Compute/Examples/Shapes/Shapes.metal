#include <metal_stdlib>

using namespace metal;

struct Rectangle {
    int2 origin;
    int2 size;
};

kernel void shapes(texture2d<half, access::read> inTexture [[texture(0)]],
                   texture2d<half, access::write> outTexture [[texture(1)]],
                   constant Rectangle &bounds [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]])
{
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    auto color = inTexture.read(gid);
//    Rectangle bounds = Rectangle { int2(0, 0), int2(1024, 1024) }; // TODO: pass this in.
    if ((gid.x < bounds.origin.x) || (gid.x >= bounds.origin.x + bounds.size.x) ||
        (gid.y < bounds.origin.y) || (gid.y >= bounds.origin.y + bounds.size.y)) {
        outTexture.write(color, gid);
    }
    const half threshold = 0.5;
    if (color.a > 0.5) {
        outTexture.write(half4(color.xyz, 1), gid);
        return;
    }
    const int radius = 20;
    const int2 position = int2(gid);
    for (int y = 1; y <= radius; y++) {
        for (int x = 1; x <= radius; x++) {
            if (half(x) * half(x) + half(y) * half(y) <= half(radius * radius)) {
                auto offset = int2(x, y);
                auto color = inTexture.read(uint2(position + offset));
                if (color.a > 0.5) {
                    outTexture.write(half4(color.xyz, 1), gid);
                    return;
                }
                offset *= int2(-1, 1);
                color = inTexture.read(uint2(position + offset));
                if (color.a > 0.5) {
                    outTexture.write(half4(color.xyz, 1), gid);
                    return;
                }
                offset *= int2(1, -1);
                color = inTexture.read(uint2(position + offset));
                if (color.a > 0.5) {
                    outTexture.write(half4(color.xyz, 1), gid);
                    return;
                }
                offset *= int2(-1, 1);
                color = inTexture.read(uint2(position + offset));
                if (color.a > 0.5) {
                    outTexture.write(half4(color.xyz, 1), gid);
                    return;
                }
            }
        }
    }
}
