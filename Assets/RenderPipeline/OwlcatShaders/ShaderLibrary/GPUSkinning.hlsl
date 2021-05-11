#ifndef OWLCAT_GPU_SKINNING_INCLUDED
#define OWLCAT_GPU_SKINNING_INCLUDED

#ifdef _GPU_SKINNING
    StructuredBuffer<float4x4> _GpuSkinningFrames;
#endif

#ifdef _GPU_SKINNING
    float3 Skin(float3 pos, float4 weights, uint4 indices)
    {
        // x - clip offset in _GpuSkinningFrames;
        // y - frame stride in _GpuSkinningFrames;
        // z - frames count in AnimationClip;
        // w - frame duration in seconds
        //float4 _GpuSkinningClipParams;

        //uint currentFrame = (uint)(frac(_Time.y / _GpuSkinningClipParams.w) * _GpuSkinningClipParams.z);
        uint currentFrame = (uint)(floor(_Time.y / _GpuSkinningClipParams.w) % _GpuSkinningClipParams.z);
        float blendFactor = frac(_Time.y / _GpuSkinningClipParams.w);
        uint nextFrame = (uint)((currentFrame + 1) % _GpuSkinningClipParams.z);

        uint offset0 = (uint)(_GpuSkinningClipParams.x + _GpuSkinningClipParams.y * currentFrame);
        uint offset1 = (uint)(_GpuSkinningClipParams.x + _GpuSkinningClipParams.y * nextFrame);

        float4x4 skinMat0 =
              _GpuSkinningFrames[offset0 + indices.x] * weights.x
            + _GpuSkinningFrames[offset0 + indices.y] * weights.y
            + _GpuSkinningFrames[offset0 + indices.z] * weights.z
            + _GpuSkinningFrames[offset0 + indices.w] * weights.w;
        float4x4 skinMat1 =
              _GpuSkinningFrames[offset1 + indices.x] * weights.x
            + _GpuSkinningFrames[offset1 + indices.y] * weights.y
            + _GpuSkinningFrames[offset1 + indices.z] * weights.z
            + _GpuSkinningFrames[offset1 + indices.w] * weights.w;

        return mul(lerp(skinMat0, skinMat1, blendFactor), float4(pos.xyz, 1.0)).xyz;
    }
#endif

#endif // OWLCAT_GPU_SKINNING_INCLUDED
