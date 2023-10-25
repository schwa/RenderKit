#import "RenderKitShaders.h"
#import "CommonTypes.h"

struct PanoramaShader {
    simd_ushort2 gridSize;
    float4 colorFactor;

    struct CameraUniforms camera;
    struct ModelTransforms modelTransforms;

#ifdef __METAL_VERSION__
    //texture2d<float> textures;
    array<texture2d<float, access::sample>, 256> textures2;

#else
    //void *textures;
#endif
};
