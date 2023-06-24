#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 original;
    float2 texCoords;
};

// NOTE: Do not edit without also editing the swift version
struct Uniforms {
    float lerp;
    float phi1;
    float phi0;
    float lambda0;
    float r;
    float scale;
};

// MARK: -

float2 equirectangular_latlon_to_xy(float2 latlon, float phi1, float phi0, float lambda0, float radius);
float2 equirectangular_xy_to_latlon(float2 xy, float phi1, float phi0, float lambda0, float radius);
float2 orthographic_latlon_to_xy(float2 latlon, float phi1, float phi0, float lambda0, float radius);
float2 orthographic_xy_to_latlon(float2 xy, float phi1, float phi0, float lambda0, float radius);
template <typename T> T lerp(T v0, T v1, float t);
template <typename T> T lerp(T v0, T v1, T t);
template <typename T> T invlerp(T v0, T v1, float v);
template <typename T> T invlerp(T v0, T v1, T v);
template <typename T> T remap(T iMin, T iMax, T oMin, T oMax, T v);
float4 danger(float2 uv, float4 color);

// MARK: -

[[vertex]]
VertexOut fisheyeVertex(
    VertexIn vertexIn [[stage_in]],
    constant Uniforms &uniforms [[buffer(2)]]
    )
{
    VertexOut vertexOut;
    vertexOut.position = float4(vertexIn.position, 0, 1);
    vertexOut.original = vertexIn.position;
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

[[fragment]]
float4 fisheyeFragment(
    VertexOut fragmentIn [[stage_in]],
    texture2d<float, access::sample> baseColorTexture [[texture(0)]],
    sampler baseColorSampler [[sampler(0)]],
    constant Uniforms &uniforms [[buffer(2)]]
    )
{
    auto position = fragmentIn.original;
    //    auto uv = fragmentIn.texCoords;
    auto uv = position; // * 0.5 + 0.5;

    auto latlon = equirectangular_xy_to_latlon(uv, uniforms.phi1, uniforms.phi0, uniforms.lambda0, uniforms.r);
    auto uv2 = orthographic_latlon_to_xy(latlon, uniforms.phi1, uniforms.phi0, uniforms.lambda0, uniforms.r);

    uv = uv * uniforms.scale * 0.5 + 0.5;
    uv2 = uv2 * uniforms.scale * 0.5 + 0.5;

//    auto r = remap(float2(-1.570796), float2(1.570796), float2(0.0), float2(1.0), latlon);

//    return float4(r, 0, 1);

    return danger(uv2, baseColorTexture.sample(baseColorSampler, lerp(uv, uv2, uniforms.lerp)));
}

// MARK: -

// https://en.wikipedia.org/wiki/Equirectangular_projection

float2 equirectangular_latlon_to_xy(float2 latlon, float phi1, float phi0, float lambda0, float radius) {
    const auto lambda = latlon.x; const auto phi = latlon.y;

    const auto x = radius * (lambda - lambda0) * cos(phi1);
    const auto y = radius * (phi - phi0);
    return float2(x, y);
}

float2 equirectangular_xy_to_latlon(float2 xy, float phi1, float phi0, float lambda0, float radius) {
    auto x = xy.x; auto y = xy.y;
    auto lambda = x / (radius * cos(phi1)) + lambda0;
    auto phi = y / radius + phi0;
    return float2(lambda, phi);
}

// https://en.wikipedia.org/wiki/Orthographic_map_projection

float2 orthographic_latlon_to_xy(float2 latlon, float phi1, float phi0, float lambda0, float radius) {
    auto lambda = latlon.x; auto phi = latlon.y;

    auto x = radius * cos(phi) * sin(lambda - lambda0);
    auto y = radius * (cos(phi0) * sin(phi) - sin(phi0) * cos(phi) * cos(lambda - lambda0));
    return float2(x, y);
}

float2 orthographic_xy_to_latlon(float2 xy, float phi1, float phi0, float lambda0, float radius) {
    const auto x = xy.x; const auto y = xy.y;

    const auto rho = sqrt(x * x + y * y);
    const auto c = asin(rho / radius);
    const auto lambda = asin(cos(c) * sin(lambda0) + (y * sin(c) * cos(lambda0)) / rho);
    const auto phi = phi0 + atan((x * sin(c)) / (rho * cos(c) * cos(lambda0) - y * sin(c) * sin(lambda0)));
    return float2(lambda, phi);
}

//float2 lerp(float2 v0, float2 v1, float t) {
//    //return v0 + t * (v1 - v0);
//    return (1 - t) * v0 + t * v1;
//}

template <typename T> T lerp(T v0, T v1, float t) {
    //return v0 + t * (v1 - v0);
    return (1 - t) * v0 + t * v1;
}

template <typename T> T lerp(T v0, T v1, T t) {
    //return v0 + t * (v1 - v0);
    return (1 - t) * v0 + t * v1;
}

template <typename T> T invlerp(T v0, T v1, float v) {
    return (v - v0) / (v1 - v0);
}

template <typename T> T invlerp(T v0, T v1, T v) {
    return (v - v0) / (v1 - v0);
}

template <typename T> T remap(T iMin, T iMax, T oMin, T oMax, T v) {
    T t = invlerp(iMin, iMax, v);
    return lerp(oMin, oMax, t);
}

float4 danger(float2 uv, float4 color) {
    if (isnan(uv.x) || isnan(uv.y)) {
        return float4(1, 0, 0, 1);
    }
    else if (isinf(uv.x) || isinf(uv.y)) {
        return float4(1, 1, 0, 1);
    }
    else if (uv.x < 0 || uv.y < 0) {
        return float4(0, 1, 0, 1);
    }
    else if (uv.x > 1 || uv.y > 1) {
        return float4(0, 0, 1, 1);
    }
    else {
        return color;
    }
}

