#ifndef OWLCAT_TERRAIN_SHADOWCASTER_PASS_INCLUDED
#define OWLCAT_TERRAIN_SHADOWCASTER_PASS_INCLUDED

#include "TerrainInput.hlsl"
#include "TerrainCommon.hlsl"
#include "../../ShaderLibrary/Shadows/Shadow.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
	float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_Position;
    #if defined(GEOMETRY_CLIP)
        float2 clip : CLIP_DISTANCE_SEMANTIC0;
    #endif
};

Varyings Vert(Attributes input)
{
    Varyings output = (Varyings) 0;
    UNITY_SETUP_INSTANCE_ID(input);
	float2 uv = 0;
    TerrainInstancing(input.positionOS, input.normalOS, uv);

    ShadowData sd = _ShadowDataBuffer[_ShadowEntryIndex];
    int matrixIndex = (int) (sd.matrixIndices[_FaceId]);
    ShadowMatrix shadowMatrix = _ShadowMatricesBuffer[matrixIndex];
    float4x4 shadowViewProjTexMatrix = shadowMatrix.worldToShadow;
	float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
	float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
	positionWS = ApplyShadowBias(positionWS, normalWS, shadowMatrix.lightDirection, shadowMatrix.depthBias, shadowMatrix.normalBias);

    output.positionCS = mul(shadowViewProjTexMatrix, float4(positionWS, 1.0));

    #if defined(GEOMETRY_CLIP)
        output.clip[0] = -GetClipDistance(output.positionCS.xy, _FaceId, 0);
		output.clip[1] = -GetClipDistance(output.positionCS.xy, _FaceId, 1);
    #endif

    /*#if UNITY_REVERSED_Z
        OUT.positionCS.z = min(OUT.positionCS.z, OUT.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        OUT.positionCS.z = max(OUT.positionCS.z, OUT.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif*/

    return output;
}

float4 Frag(Varyings IN) : SV_Target
{
    return 0;
}

#endif //OWLCAT_TERRAIN_SHADOWCASTER_PASS_INCLUDED
