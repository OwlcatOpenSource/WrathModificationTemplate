#ifndef OWLCAT_TERRAIN_GBUFFER_PASS_INCLUDED
#define OWLCAT_TERRAIN_GBUFFER_PASS_INCLUDED

#include "TerrainInput.hlsl"
#include "TerrainCommon.hlsl"
#include "../../Lighting/DeferredData.cs.hlsl"
#include "../../ShaderLibrary/GBufferUtils.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
	float4 giSampling		: TEXCOORD1;
	float3 positionWS		: TEXCOORD2;
	float3 positionOS		: TEXCOORD3;
    float3 normalWS			: TEXCOORD4;
    #if !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
        float3 tangentWS	: TEXCOORD5;
        float3 bitangentWS	: TEXCOORD6;
    #endif
	#ifdef DEFERRED_ON
		float4 viewDir		: TEXCOORD7;
	#endif
	float4 positionCS : SV_POSITION;
};

Varyings Vert(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    TerrainInstancing(input.vertex, input.normal, input.texcoord);

    output.uv = input.texcoord;

	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.vertex.xyz);

    output.positionCS = vertexInput.positionCS;
	output.positionWS = vertexInput.positionWS;
    #ifdef _TRIPLANAR
        output.positionOS = input.vertex.xyz;
    #endif

    #if !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
        float4 tangentOS = float4(cross(float3(0, 0, 1), input.normal), 1.0);
        // mikkts space compliant. only normalize when extracting normal at frag.
        float sign = tangentOS.w * GetOddNegativeScale();
        output.normalWS = TransformObjectToWorldNormal(input.normal);
        output.tangentWS = TransformObjectToWorldDir(tangentOS.xyz);
        output.bitangentWS = cross(output.normalWS, output.tangentWS) * sign;
    #else
        output.normalWS = TransformObjectToWorldNormal(input.normal);
    #endif

	#ifdef DEFERRED_ON
		output.viewDir.xyz = _WorldSpaceCameraPos - output.positionWS;
	#endif

	// We either sample GI from lightmap or SH. lightmap UV and vertex SH coefficients
    // are packed in lightmapUVOrVertexSH to save interpolator.
    // The following funcions initialize
	float2 dynamicLightmapUv = 0;
	#ifdef DYNAMICLIGHTMAP_ON
		dynamicLightmapUv = input.texcoord;
	#endif
    OUTPUT_LIGHTMAP_UV(input.texcoord, unity_LightmapST, dynamicLightmapUv, unity_DynamicLightmapST, output.giSampling);
    OUTPUT_SH(output.normalWS, output.giSampling);

    return output;
}

GBufferOutput Frag(Varyings input)
{
	float4 albedo = 0;
	float4 masks = 0;
    float3 normalWS = input.normalWS;
    #if !defined(TERRAIN_SPLAT_BASEPASS)
        MaxLayerWeights weights = GetMaxWeights(input.uv.xy);

        #if defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
            float2 sampleCoords = (input.uv.xy / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
            normalWS = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
            float3 tangentWS = cross(GetObjectToWorldMatrix()._13_23_33, normalWS);
            float3 bitangentWS = cross(normalWS, tangentWS);
        #else
            float3 tangentWS = input.tangentWS;
            float3 bitangentWS = input.bitangentWS;
        #endif

		TerrainMapping mapping = GetTerrainMapping(weights, input.uv.xy, normalWS, input.positionOS);

		float4 layersAlpha = 0;
		albedo = SplatFetchDiffuse(mapping, weights, layersAlpha);
		masks = SplatFetchMasks(mapping, weights, layersAlpha);
        normalWS = SplatFetchNormal(mapping, weights, normalWS, tangentWS, bitangentWS, input.uv, layersAlpha);
    #endif

    normalWS = normalize(normalWS);
	
	uint materialFeatures = MATERIALFEATURES_LIGHTING_ENABLED;
	#if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
		materialFeatures |= MATERIALFEATURES_SHADOWMASK;
	#endif
	#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
		materialFeatures |= MATERIALFEATURES_REFLECTIONS;
	#endif

	float4 shadowMask = float4(-1,0,0,0);
	float3 bakedGI = 0;
	SampleGI(input.giSampling, input.positionWS, normalWS, /*out bakedGI*/ bakedGI, /*out shadowMask*/ shadowMask);

	return EncodeGBuffer(
		albedo.rgb, // albedo
		normalWS,
		1 - masks.r, // smoothness
		masks.b, // metallic
		albedo.rgb * masks.g, // emission
		bakedGI,
		shadowMask,
		0, // translucency
		materialFeatures // materialFeatures
	);
}

#endif //OWLCAT_TERRAIN_INPUT_INCLUDED
