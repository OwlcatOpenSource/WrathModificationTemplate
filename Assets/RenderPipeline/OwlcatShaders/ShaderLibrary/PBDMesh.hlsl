#ifndef OWLCAT_PBD_MESH_INCLUDED
#define OWLCAT_PBD_MESH_INCLUDED

#ifdef PBD_MESH
    StructuredBuffer<float4x4> _PbdBodyWorldToLocalMatrices;
    StructuredBuffer<float3> _PbdParticlesPositionBuffer;
    StructuredBuffer<float3> _PBDNormals;
    StructuredBuffer<float4> _PBDTangents;
    float _PbdEnabledGlobal;
    float _PbdEnabledLocal;
    uint _PbdParticlesOffset;
    uint _PbdVertexOffset;
    int _PbdBodyDescriptorIndex;
#endif

#ifdef PBD_MESH
    void PbdMesh(uint vertexId, inout float3 pos, inout float3 normal, inout float4 tangent)
    {
        if (_PbdEnabledGlobal < 1 || _PbdEnabledLocal < 1)
        {
            return;  
		}

        // используем сохраненную матрицу
        // эти матрицы нужны для правильной работы MeshBody потому что вертексы лежат в local space,
        // а партиклы в world space, поэтому нужно запоминать матрицу, с помощью которой расчитывали
        // конвертацию между пространствами и хранить ее до следующего тика физики.
        float4x4 worldToLocal = _PbdBodyWorldToLocalMatrices[_PbdBodyDescriptorIndex];
        pos = mul(worldToLocal, float4(_PbdParticlesPositionBuffer[_PbdParticlesOffset + vertexId], 1)).xyz;

        normal = _PBDNormals[_PbdVertexOffset + vertexId];
        tangent.xyz = _PBDTangents[_PbdVertexOffset + vertexId].xyz;
    }
#endif

#endif // OWLCAT_PBD_MESH_INCLUDED
