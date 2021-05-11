#ifndef OWLCAT_PBD_GRASS_INCLUDED
#define OWLCAT_PBD_GRASS_INCLUDED

#ifdef PBD_GRASS
    StructuredBuffer<float3> _PbdParticlesBasePositionBuffer;
    StructuredBuffer<float3> _PbdParticlesPositionBuffer;
    float _PbdEnabledGlobal;
#endif

#ifdef PBD_GRASS
    void PbdGrass(inout float3 pos)
    {
        if (_PbdEnabledGlobal < 1)
        {
            return;  
		}

        #if defined(INDIRECT_INSTANCING)
            IndirectInstanceData instData = _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID];

            float3 rootBasePos = TransformWorldToObject(_PbdParticlesBasePositionBuffer[instData.physicsDataIndex + 0]);
            float3 headBasePos = TransformWorldToObject(_PbdParticlesBasePositionBuffer[instData.physicsDataIndex + 1]);
            float3 headPos = TransformWorldToObject(_PbdParticlesPositionBuffer[instData.physicsDataIndex + 1]);

            float3 delta = headPos - headBasePos;
            float grassLength = length(rootBasePos - headBasePos);

            float slopeFactor = pos.y / grassLength;
            pos += delta * slopeFactor * slopeFactor;
        #endif
    }
#endif

#endif // OWLCAT_PBD_GRASS_INCLUDED
