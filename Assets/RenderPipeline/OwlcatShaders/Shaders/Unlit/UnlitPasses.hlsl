#ifndef OWLCAT_UNLIT_PASSES_INCLUDED
#define OWLCAT_UNLIT_PASSES_INCLUDED

#include "UnlitInput.hlsl"
#include "../../Lighting/DeferredData.cs.hlsl"
#include "../../ShaderLibrary/GBufferUtils.hlsl"

struct Attributes
{
    float4 positionOS       : POSITION;
	float3 normalOS			: NORMAL0;
    float2 uv               : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv				: TEXCOORD0;
    float fogCoord			: TEXCOORD1;
	float3 positionWS		: TEXCOORD2;
	float3 normalWS			: TEXCOORD3;
	#ifdef OCCLUDED_OBJECT_CLIP
		float4 viewDir		: TEXCOORD4;
	#endif
    float4 positionCS		: SV_POSITION;

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings GBufferVertex(Attributes input)
{
	Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInput.positionCS;
	output.positionWS = vertexInput.positionWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

	#ifdef OCCLUDED_OBJECT_CLIP
		output.viewDir.xyz = _WorldSpaceCameraPos - output.positionWS;
	#endif

	VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
	output.normalWS = normalInput.normalWS;

    return output;
}

GBufferOutput GBufferFragment(Varyings input)
{
	float4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
	AlphaDiscard(albedoAlpha.a, _Cutoff);

	#ifdef OCCLUDED_OBJECT_CLIP
		if (_OccludedObjectHighlightingFeatureEnabled > 0)
		{
			float4 occludedTex = SAMPLE_TEXTURE2D_LOD(_OccludedDepthRT, s_linear_clamp_sampler, input.positionCS.xy * _ScreenSize.zw, 0);
			float viewDirLength = length(input.viewDir);
			if (input.positionCS.w < occludedTex.r || viewDirLength < _OccludedObjectClipNearCameraDistance)
			{
				//float noise = cnoise(input.positionWS.xyz * _OccludedObjectClipNoiseTiling) * .5 + .5;
				float noise = SAMPLE_TEXTURE3D(_OccludedObjectNoiseMap3D, s_linear_repeat_sampler, input.positionWS.xyz).r;
				float distanceAlpha = 1 - viewDirLength / _OccludedObjectClipNearCameraDistance;
				clip(_OccludedObjectClipTreshold - max(distanceAlpha, occludedTex.g) * _OccludedObjectAlphaScale + noise);
			}
		}
	#endif

	#ifdef DEBUG_DISPLAY
		albedoAlpha.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, albedoAlpha.rgb);
		#ifdef OCCLUDED_OBJECT_CLIP
			if (_DebugMaterial == DEBUGMATERIAL_OCCLUDED_OBJECT_CLIP)
			{
				albedoAlpha.rgb = 1;
			}
		#endif
	#endif

	return EncodeGBuffer(
		0, // albedo
		input.normalWS, // normal
		0, // smoothness
		0, // metallic
		albedoAlpha.rgb, // emission
		0, // bakedGI
		0, // shadowMask,
		0, // translucency
		0 // materialFeatures
	);
}

Varyings UnlitVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInput.positionCS;
	output.positionWS = vertexInput.positionWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.fogCoord = ComputeFogFactor(vertexInput.positionCS.w);

    return output;
}

half4 UnlitFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half2 uv = input.uv;
    half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    half3 color = texColor.rgb * _BaseColor.rgb;
    half alpha = texColor.a * _BaseColor.a;
    AlphaDiscard(alpha, _Cutoff);

	#ifdef DEBUG_DISPLAY
		color.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, color.rgb);

		if (_DebugLightingMode != DEBUGLIGHTINGMODE_EMISSION)
		{
			color = 0;
		}
	#endif

	FinalColorOutput(color);

	// туман нужно миксовать после перевода в Gamma-space, потому что пост-процессный туман работает через аддитивный блендинг в гамме (т.е. его невозможно перевести в линеар)
	// поэтому делаем все в гамме
	color = MixFog(color, input.fogCoord);

	// FOW нужно делать ПОСЛЕ конверта в gamma-space, иначе будут артефакты в виде ступенчатого градиента
	#ifdef SUPPORT_FOG_OF_WAR
		ApplyFogOfWar(input.positionWS, color.rgb);
	#endif

	#if defined(_ALPHAPREMULTIPLY_ON) && defined(_TRANSPARENT_ON)
		color *= alpha;
	#endif

    return half4(color, alpha);
}

#endif // OWLCAT_UNLIT_PASSES_INCLUDED
