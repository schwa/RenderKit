#pragma once

#ifdef __METAL_VERSION__
struct UblitMaterialArgumentBuffer {
    texture2d<float, access::sample> baseColorTexture;
    sampler baseColorSampler;
};
#endif
