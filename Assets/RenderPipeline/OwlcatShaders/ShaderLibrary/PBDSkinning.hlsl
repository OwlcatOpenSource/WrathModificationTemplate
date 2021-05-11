#ifndef OWLCAT_PBD_SKINNING_INCLUDED
#define OWLCAT_PBD_SKINNING_INCLUDED

#ifdef PBD_SKINNING
    StructuredBuffer<float4x4> _PbdBindposes;
    Buffer<int> _PbdSkinnedBodyBoneIndicesMap;
    float _PbdEnabledGlobal;
    float _PbdEnabledLocal;
    int _PbdBonesOffset;
    int _PbdBoneIndicesOffset;
    float4 _PbdWeightMask;
#endif

#ifdef PBD_SKINNING
    void PbdSkin(float4 weights, uint4 indices, inout float3 pos, inout float3 normal, inout float4 tangent)
    {
        if (_PbdEnabledGlobal < 1 || _PbdEnabledLocal < 1)
        {
            return;  
		}

        // корректировка весов
        // меши могут использовать от 1 до 4 костей
        // если меш использует меньше 4 костей, то лишние веса почему не зануляются движком
        // приходится делать это вручную
        weights = weights * _PbdWeightMask;

        // ремапинг индексов
        indices.x = (uint)_PbdSkinnedBodyBoneIndicesMap[indices.x + _PbdBoneIndicesOffset];
        indices.y = (uint)_PbdSkinnedBodyBoneIndicesMap[indices.y + _PbdBoneIndicesOffset];
        indices.z = (uint)_PbdSkinnedBodyBoneIndicesMap[indices.z + _PbdBoneIndicesOffset];
        indices.w = (uint)_PbdSkinnedBodyBoneIndicesMap[indices.w + _PbdBoneIndicesOffset];

        float4x4 skinMat =
              _PbdBindposes[indices.x + _PbdBonesOffset] * weights.x
            + _PbdBindposes[indices.y + _PbdBonesOffset] * weights.y
            + _PbdBindposes[indices.z + _PbdBonesOffset] * weights.z
            + _PbdBindposes[indices.w + _PbdBonesOffset] * weights.w;

        pos = mul(skinMat, float4(pos.xyz, 1.0)).xyz;

        #ifdef PBD_SKINNING_NORM
            normal = mul(skinMat, float4(normal, 0.0)).xyz;
        #endif

        #ifdef PBD_SKINNING_TANG
            tangent.xyz = mul(skinMat, float4(tangent.xyz, 0.0)).xyz;
        #endif
    }
#endif

#endif // OWLCAT_PBD_SKINNING_INCLUDED
