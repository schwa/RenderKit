#import "RenderKitShaders.h"
#import "CommonTypes.h"

struct PanoramaShader {
    simd_ushort2 gridSize;
    float4 colorFactor;

    struct CameraUniforms camera;
    struct ModelTransforms modelTransforms;

#ifdef __METAL_VERSION__
    array<texture2d<float, access::sample>, 12> textures;
#else
    void *textures;
#endif
};
