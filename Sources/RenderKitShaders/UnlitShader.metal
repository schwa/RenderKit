#import "include/RenderKitShaders.h"
#import "include/UnlitShader.h"

typedef SimpleVertex Vertex;

struct Fragment {
    float4 position [[position]]; // in projection space
    ushort material_id;
};

// MARK: -

[[vertex]]
Fragment unlitVertexShader(
    Vertex in [[stage_in]],
    ushort instance_id[[instance_id]],
    constant CameraUniforms &camera[[buffer(1)]],
    constant ModelTransforms *models[[buffer(2)]]
)
{
    const ModelTransforms model = models[instance_id];
    const float4 modelVertex = model.modelViewMatrix * float4(in.position, 1.0);
    return {
        .position = camera.projectionMatrix * modelVertex,
        .material_id = 0, // instancedModelUniforms[instnace_id].material_id
    };
}

[[fragment]]
vector_float4 unlitFragmentShader(
    Fragment in [[stage_in]],
    constant UnlitMaterial *materials [[buffer(2)]]
    )
{
    return materials[in.material_id].color;
}
