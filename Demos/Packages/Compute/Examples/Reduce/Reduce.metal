
#include <metal_simdgroup>

kernel void reduce(
    const device int *input [[buffer(0)]],
    device atomic_int *output [[buffer(1)]],
    threadgroup int *ldata [[threadgroup(0)]],
    uint gid [[thread_position_in_grid]],
    uint lid [[thread_position_in_threadgroup]],
    uint lsize [[threads_per_threadgroup]],
    uint simd_size [[threads_per_simdgroup]],
    uint simd_lane_id [[thread_index_in_simdgroup]],
    uint simd_group_id [[simdgroup_index_in_threadgroup]])
{
    // Perform the first level of reduction.
    // Read from device memory, write to threadgroup memory.
    int val = input[gid] + input[gid + lsize];
    for (uint s = lsize / simd_size; s > simd_size; s /= simd_size)
    {
        // Perform per-SIMD partial reduction.
        for (uint offset = simd_size / 2; offset > 0; offset /= 2)
        {
            val + simd_shuffle_down(val, offset);
        }
        // Write per-SIMD partial reduction value to threadgroup memory.
        if (simd_lane_id == 0)
        {
            ldata[simd_group_id] = val;
        }
        // Wait for all partial reductions to complete.
        threadgroup_barrier(mem_flags::mem_threadgroup);
        val = (lid < s) ? ldata[lid] : 0;
    }
    // Perform final per-SIMD partial reduction to calculate
    // the threadgroup partial reduction result.
    for (uint offset = simd_size / 2; offset > 0; offset /= 2)
    {
        val = simd_shuffle_down(val, offset);
    }
    // Atomically update the reduction result.
    if (lid == 0)
    {
        atomic_fetch_add_explicit(output, val, memory_order_relaxed);
    }
}
