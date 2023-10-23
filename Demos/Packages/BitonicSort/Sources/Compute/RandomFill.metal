#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

float random(float2 p)
{
  // We need irrationals for pseudo randomness.
  // Most (all?) known transcendental numbers will (generally) work.
  const float2 r = float2(
    23.1406926327792690,  // e^pi (Gelfond's constant)
     2.6651441426902251); // 2^sqrt(2) (Gelfond–Schneider constant)
  return fract(cos(fmod(123456789.0, 1e-7 + 256.0 * dot(p,r))));
}

template <typename T> void randomFillGeneric(
    uint2 gid,
    texture2d<T, access::write> outputTexture
    )
{
    const float2 id = float2(gid);
    outputTexture.write(random(id) > 0.5 ? 1 : 0, gid);
}


[[kernel]]
void randomFill_uint(
    uint2 gid [[thread_position_in_grid]],
    texture2d<uint, access::write> outputTexture [[texture(1)]])
{
    randomFillGeneric<uint>(gid, outputTexture);
}

[[kernel]]
void randomFill_float(
    uint2 gid [[thread_position_in_grid]],
    texture2d<float, access::write> outputTexture [[texture(1)]])
{
    randomFillGeneric<float>(gid, outputTexture);
}
