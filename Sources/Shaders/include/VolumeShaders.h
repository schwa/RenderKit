#import "Support.h"


//#pragma pack(push, 1)
//struct VolumeUniforms {
//    simd_float4x4 modelMatrix;
//    simd_float4x4 viewMatrix;
//};
//#pragma pack(pop)


#pragma pack(push, 1)
struct VolumeInstance {
    float offsetZ;
    float textureZ;
};
#pragma pack(pop)
