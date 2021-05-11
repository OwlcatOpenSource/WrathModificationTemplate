#ifndef OWLCAT_LIT_GBUFFER_PASS_INCLUDED
#define OWLCAT_LIT_GBUFFER_PASS_INCLUDED

#include "LitInput.hlsl"
#include "../../ShaderLibrary/GPUSkinning.hlsl"
#include "../../Lighting/DeferredData.cs.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/GBufferUtils.hlsl"
#ifdef VAT_ENABLED
	#include "../../ShaderLibrary/VAT.hlsl"
#endif
#ifdef VERTEX_ANIMATION_ENABLED
	#include "../../ShaderLibrary/VertexAnimation.hlsl"
#endif

#if defined(PASS_SCENESELECTIONPASS)
	float _ObjectId;
	float _PassValue;
#endif

struct Attributes
{
    float4 positionOS			: POSITION;
    float3 normalOS				: NORMAL;
    float4 tangentOS			: TANGENT;
    float2 texcoord				: TEXCOORD0;
    float2 lightmapUV			: TEXCOORD1;
	#ifdef DYNAMICLIGHTMAP_ON
		float2 dynamicLightmapUv: TEXCOORD2;
	#endif
    #if defined(_GPU_SKINNING) || defined(PBD_SKINNING)
        float4 blendWeights		: BLENDWEIGHTS0;
        uint4 blendIndices		: BLENDINDICES0;
    #endif
	#if defined(PBD_MESH)
		uint vertexId			: VERTEXID_SEMANTIC;
	#endif
	#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED)
		float4 color			: COLOR0;
	#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 uv               : TEXCOORD0;
	float2 uv2				: TEXCOORD1;
	float4 giSampling		: TEXCOORD2;
	float3 positionWS		: TEXCOORD3;
    float3 normalWS         : TEXCOORD4;
	#if defined(_NORMALMAP)
        float3 tangentWS    : TEXCOORD5;
        float3 bitangentWS	: TEXCOORD6;
	#endif
	float4 viewDir			: TEXCOORD7;
	#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || (defined(DEBUG_DISPLAY) && defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED))
		float4 color			: TEXCOORD8;
	#endif
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////
Varyings GBufferVertex(Attributes input)
{
    Varyings output = (Varyings) 0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    #ifdef _GPU_SKINNING
        input.positionOS.xyz = Skin(input.positionOS.xyz, input.blendWeights, input.blendIndices);
    #endif

	#ifdef PBD_SKINNING
		PbdSkin(input.blendWeights, input.blendIndices, input.positionOS.xyz, input.normalOS.xyz, input.tangentOS.xyzw);
	#endif

	#ifdef PBD_MESH
		PbdMesh(input.vertexId, input.positionOS.xyz, input.normalOS.xyz, input.tangentOS.xyzw);
	#endif

	#ifdef PBD_GRASS
		PbdGrass(input.positionOS.xyz);
	#endif

	#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || (defined(DEBUG_DISPLAY) && defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED))
		output.color = input.color;
	#endif

	#ifdef VAT_ENABLED
		VAT(input.lightmapUV.xy, input.color.rgb, input.positionOS.xyz, input.normalOS.xyz);
	#endif

	#ifdef VERTEX_ANIMATION_ENABLED
		VertexAnimation(input.color, input.normalOS, input.positionOS.xyz);
	#endif

	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInput.positionCS;
	output.positionWS = vertexInput.positionWS;
	output.viewDir.xyz = _WorldSpaceCameraPos - output.positionWS;
    
    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
	#if DISSOLVE_ON
		output.uv.zw = TRANSFORM_TEX(input.texcoord, _DissolveMap);
	#endif
	#if ADDITIONAL_ALBEDO
		output.uv2.xy = TRANSFORM_TEX(input.texcoord, _AdditionalAlbedoMap);
	#endif

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #ifdef _NORMALMAP
        output.normalWS = normalInput.normalWS;
        output.tangentWS = normalInput.tangentWS;
        output.bitangentWS = normalInput.bitangentWS;
    #else
        output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    #endif

	// We either sample GI from lightmap or SH. lightmap UV and vertex SH coefficients
    // are packed in lightmapUVOrVertexSH to save interpolator.
    // The following funcions initialize
	float2 dynamicLightmapUv = 0;
	#ifdef DYNAMICLIGHTMAP_ON
		dynamicLightmapUv = input.dynamicLightmapUv;
	#endif
    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, dynamicLightmapUv, unity_DynamicLightmapST, output.giSampling);
    OUTPUT_SH(output.normalWS, output.giSampling);

    return output;
}


#ifdef _DOUBLESIDED_ON
GBufferOutput GBufferFragment(Varyings input, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC)
#else
GBufferOutput GBufferFragment(Varyings input)
#endif
{
    UNITY_SETUP_INSTANCE_ID(input);

    FLIP_DOUBLESIDED(input, cullFace);

	#if defined(PASS_SCENESELECTIONPASS)
		GBufferOutput output = (GBufferOutput)0;
		output.normal = float4(_ObjectId, _PassValue, 1.0, 1.0);
		return output;
	#endif

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

	SurfaceData surfaceData;
	InitializeStandardLitSurfaceData(input.uv.xy, input.positionCS.xy, surfaceData);

	#if defined(_NORMALMAP)
        float3 normalWS = TransformTangentToWorld(surfaceData.normalTS, float3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
    #else
        float3 normalWS = input.normalWS;
    #endif

	normalWS = normalize(normalWS);

	#if defined(INDIRECT_INSTANCING)
		#ifdef USE_GROUND_COLOR
			surfaceData.albedo = lerp(surfaceData.albedo, _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID].tintColor, _GroundColorPower * (1 - input.color.r));
		#endif
	#endif

	uint materialFeatures = MATERIALFEATURES_LIGHTING_ENABLED;
	#if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON) || defined(INDIRECT_INSTANCING)
		materialFeatures |= MATERIALFEATURES_SHADOWMASK;
	#endif
	#if defined(_TRANSLUCENT)
		materialFeatures |= MATERIALFEATURES_TRANSLUCENT;
	#endif
	#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
		materialFeatures |= MATERIALFEATURES_REFLECTIONS;
	#endif

	if (_WrapDiffuseFactor > 0)
	{
		materialFeatures |= MATERIALFEATURES_WRAP_DIFFUSE;
	}

	float3 bakedGI = 0;
	float4 shadowmask = 0;
    SampleGI(input.giSampling, input.positionWS, normalWS, /*out bakedGI*/ bakedGI.rgb, /*out shadowMask*/ shadowmask);

	Dissolve(input.uv.zw, surfaceData);

	#ifdef DEFERRED_ON
		AdditionalAlbedoMix(input.uv2.xy, surfaceData);

		float3 viewDirectionWS = normalize(input.viewDir.xyz);
		if(_RimLighting)
		{
			RimLighting(normalWS, viewDirectionWS, surfaceData);
		}

		#ifdef DEBUG_DISPLAY
			surfaceData.albedo.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, surfaceData.albedo.rgb);

			float4 vertexColor = 0;
			#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED)
				vertexColor = input.color;
			#endif

			surfaceData.albedo.rgb = GetVertexAttributeDebug(vertexColor, surfaceData.albedo.rgb);

			#ifdef OCCLUDED_OBJECT_CLIP
				if (_DebugMaterial == DEBUGMATERIAL_OCCLUDED_OBJECT_CLIP)
				{
					surfaceData.albedo = 1;
				}
			#endif
		#endif
	#endif

	return EncodeGBuffer(
		surfaceData.albedo.rgb, // albedo
		normalWS,
		surfaceData.smoothness, // smoothness
		surfaceData.metallic, // metallic
		surfaceData.emission.rgb, // emission
		bakedGI, // bakedGI
		shadowmask, // shadowMask,
		surfaceData.translucency * _Thickness * _TranslucencyColor.rgb, // translucency
		materialFeatures // materialFeatures
	);
}

#endif // OWLCAT_LIT_GBUFFER_PASS_INCLUDED
