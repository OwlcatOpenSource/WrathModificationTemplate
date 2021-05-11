#ifndef OWLCAT_LIT_SHADOWCASTER_PASS_INCLUDED
#define OWLCAT_LIT_SHADOWCASTER_PASS_INCLUDED

#include "LitInput.hlsl"
#include "../../ShaderLibrary/Shadows/Shadow.hlsl"
#ifdef VAT_ENABLED
	#include "../../ShaderLibrary/VAT.hlsl"
#endif

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    #ifdef VAT_ENABLED
        float2 lightmapUV : TEXCOORD1;
    #endif
	#if (VAT_ENABLED)
		float4 color			: COLOR0;
	#endif
    #if defined(_GPU_SKINNING) || defined(PBD_SKINNING)
        float4 blendWeights		: BLENDWEIGHTS0;
        uint4 blendIndices		: BLENDINDICES0;
    #endif
	#if defined(PBD_MESH)
		uint vertexId			: VERTEXID_SEMANTIC;
	#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float4 positionCS : SV_POSITION;
    #if defined(GEOMETRY_CLIP)
        float2 clip : CLIP_DISTANCE_SEMANTIC0;
    #endif
};

// ------------------------------------------------------------------
// ---------------------Multi pass variants--------------------------
Varyings Vertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    #ifdef VAT_ENABLED
		VAT(input.lightmapUV.xy, input.color.rgb, input.positionOS.xyz, input.normalOS.xyz);
	#endif

    #ifdef PBD_SKINNING
        float3 norm = 0;
        float4 tang = 0;
		PbdSkin(input.blendWeights, input.blendIndices, input.positionOS.xyz, norm, tang);
	#endif

	#ifdef PBD_MESH
        float3 norm = 0;
        float4 tang = 0;
		PbdMesh(input.vertexId, input.positionOS.xyz, norm, tang);
	#endif

    #ifdef PBD_GRASS
		PbdGrass(input.positionOS.xyz);
	#endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    ShadowData sd = _ShadowDataBuffer[_ShadowEntryIndex];
    int matrixIndex = (int)(sd.matrixIndices[_FaceId]);
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

float4 Fragment(Varyings input) : SV_TARGET
{
    #if defined(_ALPHATEST_ON)
        float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

        // calculate cutoff
        if (_BaseColorBlending > 0)
        {
            _BaseColor.a = 1;  
		}
        float alpha = Alpha(albedo.a, _BaseColor, _Cutoff);
    #endif

	// dissolve cutoff
	SurfaceData emptySd = (SurfaceData)0;
	Dissolve(input.uv, emptySd);

    return 0;
}

#endif // OWLCAT_LIT_SHADOWCASTER_PASS_INCLUDED
