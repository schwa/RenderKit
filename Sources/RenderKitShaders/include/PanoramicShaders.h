#import "RenderKitShaders.h"
#import "CommonTypes.h"

struct PanoramaFragmentUniforms {
    simd_ushort2 gridSize;
    float4 colorFactor;
};

struct PanoramaShader {
    simd_ushort2 gridSize;
    float4 colorFactor;

    struct CameraUniforms camera;
    struct ModelTransforms modelTransforms;

#ifdef __METAL_VERSION__
    device texture2d<float> *textures;
#else
    void *textures;
#endif
};
