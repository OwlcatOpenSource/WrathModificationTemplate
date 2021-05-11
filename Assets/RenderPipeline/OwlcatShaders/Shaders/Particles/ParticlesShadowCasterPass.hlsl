#ifndef OWLCAT_LIT_SHADOWCASTER_PASS_INCLUDED
#define OWLCAT_LIT_SHADOWCASTER_PASS_INCLUDED

#include "ParticlesInput.hlsl"
#include "../../ShaderLibrary/Shadows/Shadow.hlsl"
#ifdef VAT_ENABLED
	#include "../../ShaderLibrary/VAT.hlsl"
#endif

struct Attributes
{
    float4 positionOS			: POSITION;
	float4 color				: COLOR0;
    float3 normalOS				: NORMAL;
    float4 texcoord				: TEXCOORD0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON) || defined(COLOR_ALPHA_RAMP) || defined(VAT_ENABLED)
		float4 customData1		: TEXCOORD1;
	#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float4 color				: COLOR0;
	float4 uv					: TEXCOORD0;
	#if defined(TEXTURE1_ON) || defined(_NORMALMAP)
		float4 uv1				: TEXCOORD1;
	#endif
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		float4 noiseUv			: TEXCOORD2;
	#endif
    float4 positionCS			: SV_POSITION;
    #if defined(GEOMETRY_CLIP)
        float2 clip : CLIP_DISTANCE_SEMANTIC0;
    #endif
};

// ------------------------------------------------------------------
// ---------------------Multi pass variants--------------------------
Varyings Vertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

	#ifdef VAT_ENABLED
		VAT(input.customData1.xy, input.color.rgb, input.positionOS.xyz, input.normalOS.xyz);
	#endif

	float particleID = 0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		particleID = input.customData1.x;
	#endif

	float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);

	#ifdef WORLD_UV_XZ
		input.texcoord.xy = positionWS.xz;
	#endif

	VaryingsUv uvInput = GetVaryingsUv(input.texcoord, particleID);

	output.uv.xy = uvInput.tex0Uv;
	output.uv.zw = uvInput.originalUv;

	#if defined(TEXTURE1_ON)
		output.uv1.xy = uvInput.tex1Uv;
	#endif

	#if defined(NOISE0_ON)
		output.noiseUv.xy = uvInput.noiseUv0;
	#endif

	#if defined(NOISE1_ON)
		output.noiseUv.zw = uvInput.noiseUv1;
	#endif

    ShadowData sd = _ShadowDataBuffer[_ShadowEntryIndex];
    int matrixIndex = (int)(sd.matrixIndices[_FaceId]);
	ShadowMatrix shadowMatrix = _ShadowMatricesBuffer[matrixIndex];
    float4x4 shadowViewProjTexMatrix = shadowMatrix.worldToShadow;
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
    float4 uv1 = 0;
	#if defined(TEXTURE1_ON) || defined(_NORMALMAP)
		uv1 = input.uv1;
	#endif

	float alphaRampOffset = 0;
	#if defined(COLOR_ALPHA_RAMP)
		alphaRampOffset = input.fluidAndRampUvAndOpacityFalloff.z;
	#endif
	float4 noiseUv = 0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		noiseUv = input.noiseUv;
	#endif
	float2 fluidFogUv = 0;
	#if defined(FLUID_FOG)
		fluidFogUv = input.fluidAndRampUvAndOpacityFalloff.xy;
	#endif
	SurfaceUv surfaceUv = GetSurfaceUv(input.uv, uv1, alphaRampOffset, noiseUv, fluidFogUv, 0);
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(surfaceUv, input.color, 1, 1, surfaceData);
    return 0;
}

#endif // OWLCAT_LIT_SHADOWCASTER_PASS_INCLUDED
