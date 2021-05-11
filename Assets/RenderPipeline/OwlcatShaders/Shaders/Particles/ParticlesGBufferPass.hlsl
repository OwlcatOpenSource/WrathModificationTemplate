#ifndef OWLCAT_PARTICLES_GBUFFER_PASS_INCLUDED
#define OWLCAT_PARTICLES_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "ParticlesInput.hlsl"
#include "../../Lighting/DeferredData.cs.hlsl"
#include "../../ShaderLibrary/GBufferUtils.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"
#ifdef VAT_ENABLED
	#include "../../ShaderLibrary/VAT.hlsl"
#endif

#if defined(PASS_SCENESELECTIONPASS)
	float _ObjectId;
	float _PassValue;
#endif

struct Attributes
{
    float4 positionOS   : POSITION;
	float4 color		: COLOR0;
	float3 normalOS     : NORMAL;
	#if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
		float4 tangentOS    : TANGENT;
	#endif
    float4 texcoord     : TEXCOORD0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON) || defined(COLOR_ALPHA_RAMP) || defined(VAT_ENABLED)
		float4 customData1		: TEXCOORD1;
	#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float4 color			: COLOR0;
    float4 uv               : TEXCOORD0;
	float4 giSampling		: TEXCOORD2;
	float3 positionWS       : TEXCOORD3;
    float3 normalWS         : TEXCOORD4;
	#if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
        float3 tangentWS    : TEXCOORD5;
        float3 bitangentWS  : TEXCOORD6;
	#endif
	#if defined(TEXTURE1_ON) || defined(_NORMALMAP)
		float4 uv1			: TEXCOORD7;
	#endif
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		float4 noiseUv		: TEXCOORD8;
	#endif
	#if defined(FLUID_FOG) || defined(COLOR_ALPHA_RAMP) || defined(OPACITY_FALLOFF)
		float4 fluidAndRampUvAndOpacityFalloff	: TEXCOORD10;
	#endif
	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		float2 emissionUv		: TEXCOORD11;
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

	#ifdef VAT_ENABLED
		VAT(input.customData1.xy, input.color.rgb, input.positionOS.xyz, input.normalOS.xyz);
	#endif

	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
	output.positionCS = vertexInput.positionCS;
	output.positionWS = vertexInput.positionWS;

	output.color = GetVertexOutputColor(input.color);
    
	float particleID = 0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		particleID = input.customData1.x;
	#endif

	#ifdef WORLD_UV_XZ
		input.texcoord.xy = vertexInput.positionWS.xz;
	#endif

	VaryingsUv uvInput = GetVaryingsUv(input.texcoord, particleID);

	output.uv.xy = uvInput.tex0Uv;
	output.uv.zw = uvInput.originalUv;

	#if defined(TEXTURE1_ON)
		output.uv1.xy = uvInput.tex1Uv;
	#endif

	#if defined(_NORMALMAP)
		output.uv1.zw = uvInput.bumpUv;
	#endif

	#if defined(NOISE0_ON)
		output.noiseUv.xy = uvInput.noiseUv0;
	#endif

	#if defined(NOISE1_ON)
		output.noiseUv.zw = uvInput.noiseUv1;
	#endif

	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		output.emissionUv = uvInput.emissionUv;
	#endif

	#if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
		VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

		#if defined(OVERRIDE_NORMAL_ON) && defined(PARTICLES_LIGHTING_ON)
			normalInput.normalWS = _WorldSpaceCameraPos - vertexInput.positionWS;
		#endif

		#ifdef _NORMALMAP
			output.normalWS = normalInput.normalWS;
			output.tangentWS = normalInput.tangentWS;
			output.bitangentWS = normalInput.bitangentWS;
		#else
			output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
		#endif
	#else
		VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
		output.normalWS = normalInput.normalWS;
	#endif

	OUTPUT_SH(output.normalWS, output.giSampling);

	#if defined(FLUID_FOG)
		output.fluidAndRampUvAndOpacityFalloff.xy = TRANSFORM_TEX(output.positionWS.xz, _FluidFogMask);
	#endif

	#if defined(OPACITY_FALLOFF)
		float3 viewDir = normalize(_WorldSpaceCameraPos - vertexInput.positionWS);
		float VdotN = dot(viewDir.xyz, output.normalWS);
		float vertexNormalsSlope = max(0.0, abs(VdotN));
		#if defined(INVERT_OPACITY_FALLOFF)
			float2 madCoeff = float2(1, -1);
		#else
			float2 madCoeff = float2(0, 1);
		#endif
			vertexNormalsSlope = saturate(madCoeff.x + madCoeff.y * vertexNormalsSlope);
			output.fluidAndRampUvAndOpacityFalloff.w = pow(vertexNormalsSlope, _OpacityFalloff);
	#endif

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

	float opacityFalloffFactor = 1;
	#if defined(OPACITY_FALLOFF)
		opacityFalloffFactor = input.fluidAndRampUvAndOpacityFalloff.w;
	#endif
	float2 fluidFogUv = 0;
	#if defined(FLUID_FOG)
		fluidFogUv = input.fluidAndRampUvAndOpacityFalloff.xy;
	#endif
	float2 emissionUv = 0;
	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		emissionUv = input.emissionUv;
	#endif
	SurfaceUv surfaceUv = GetSurfaceUv(input.uv, uv1, alphaRampOffset, noiseUv, fluidFogUv, emissionUv);
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(surfaceUv, input.color, 1, opacityFalloffFactor, surfaceData);

    #if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
        float3 normalWS = TransformTangentToWorld(surfaceData.normalTS, float3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
    #else
        float3 normalWS = normalize(input.normalWS);
    #endif

	float3 bakedGI = 0;
	float4 shadowMask = 1;
	SampleGI(input.giSampling, input.positionWS, normalWS, bakedGI, shadowMask);

	uint materialFeatures = 0;
	#if defined(PARTICLES_LIGHTING_ON)
		materialFeatures |= MATERIALFEATURES_LIGHTING_ENABLED;
		if (_WrapDiffuseFactor > 0)
		{
			materialFeatures |= MATERIALFEATURES_WRAP_DIFFUSE;
		}
		#if defined(_TRANSLUCENT)
			materialFeatures |= MATERIALFEATURES_TRANSLUCENT;
		#endif
		#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
			materialFeatures |= MATERIALFEATURES_REFLECTIONS;
		#endif
	#else
		#if !defined(DEFERRED_ON)
			FinalColorOutput(surfaceData.albedo.rgb);
		#endif
	#endif

	#if defined(PASS_SCENESELECTIONPASS)
		GBufferOutput output = (GBufferOutput)0;
		#ifdef DEFERRED_ON
			output.color = float4(_ObjectId, _PassValue, 1.0, 1.0);
			output.translucency = float4(_ObjectId, _PassValue, 1.0, 1.0);
		#endif
		output.normal = float4(_ObjectId, _PassValue, 1.0, 1.0);
		output.bakedGI = float4(_ObjectId, _PassValue, 1.0, 1.0);
		output.shadowmask = float4(_ObjectId, _PassValue, 1.0, 1.0);
		return output;
	#endif

	#if defined(DEFERRED_ON)
		#ifdef DEBUG_DISPLAY

			if(_DebugMipMap > 0)
			{
				surfaceData.albedo.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, surfaceData.albedo.rgb);
			}

			float4 vertexColor = 0;
			vertexColor = input.color;

			if (_DebugVertexAttribute != 0)
			{
				surfaceData.albedo.rgb = GetVertexAttributeDebug(vertexColor, surfaceData.albedo.rgb);
			}
		#endif
	#endif

	surfaceData.albedo.rgb = clamp(surfaceData.albedo.rgb, float3(0, 0, 0), _HdrColorClamp.xxx);

	return EncodeGBuffer(
		surfaceData.albedo.rgb, // albedo
		normalWS,
		surfaceData.smoothness, // smoothness
		surfaceData.metallic, // metallic
		surfaceData.emission.rgb, // emission
		bakedGI, // bakedGI
		shadowMask, // shadowMask,
		surfaceData.translucency * _Thickness * _TranslucencyColor.rgb, // translucency
		materialFeatures // materialFeatures
	);
}

#endif // OWLCAT_PARTICLES_GBUFFER_PASS_INCLUDED
