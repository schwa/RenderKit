#import "Support.h"


#pragma pack(push, 1)
struct TransferFunctionParameters {
    float m;
};
#pragma pack(pop)

#pragma pack(push, 1)
struct VolumeTransforms {
    simd_float4x4 modelViewMatrix;
    simd_float4x4 textureMatrix;
};
#pragma pack(pop)


#pragma pack(push, 1)
struct VolumeInstance {
    float offsetZ;
    float textureZ;
};
#pragma pack(pop)
