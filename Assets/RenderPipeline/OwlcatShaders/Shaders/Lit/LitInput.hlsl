#ifndef OWLCAT_LIT_INPUT_INCLUDED
#define OWLCAT_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseMap_TexelSize;
float4 _BaseMap_MipInfo;
float4 _BaseColor;
float _BaseColorBlending;
float _Cutoff;
float _AlphaToCoverage;
float _Roughness;
float _Metallic;
float _BumpScale;
float _RimLighting;
float4 _RimColor;
float _RimPower;
float4 _EmissionColor;
float _EmissionColorFactor;
float _EmissionColorScale;
float _EmissionMapUsage;
float _EmissionAlbedoSuppression;
float _EmissionColorScaleMeta;
float4 _DoubleSidedConstants;

// Dissolve
float4 _DissolveMap_ST;
float4 _DissolveNoiseMap_ST;
float _Dissolve;
float _DissolveWidth;
float4 _DissolveColor;
float _DissolveColorScale;
float _DissolveCutout;
float _DissolveEmission;
float _DissolveNoiseScale;

// Additional albedo
float4 _AdditionalAlbedoMap_ST;
float _AdditionalAlbedoFactor;
float _AdditionalAlbedoColorScale;
float _AdditionalAlbedoColorClamp;
float _AdditionalAlbedoAlphaScale;
float4 _AdditionalAlbedoColor;

// Distortion
float _DistortionThicknessScale;
float _Distortion;
float _DistortionColorFactor;
float _DistortionDoesNotUseAlpha;
float2 _DistortionOffset;

// Translucency
float _Thickness;
float3 _TranslucencyColor;

// GPU Skinning
// x - clip offset in _GpuSkinningFrames;
// y - frame stride in _GpuSkinningFrames;
// z - frames count in AnimationClip;
// w - frame duration in seconds
float4 _GpuSkinningClipParams;

// Vertex Animation
float _GroundColorPower;

float _WrapDiffuseFactor;

#if defined(VAT_ENABLED)
	float _VatNumOfFrames;
	float _VatPosMin;
	float _VatPosMax;
	float _VatPivMin;
	float _VatPivMax;
	//float _VatPadPowTwo;
	float _VatTextureSizeX;
	float _VatTextureSizeY;
	//float _VatPaddedSizeX;
	//float _VatPaddedSizeY;
	float _VatLerp;
	float _VatType;
	float _VatCurrentFrame;
#endif

#if defined(VERTEX_ANIMATION_ENABLED)
	float _VaPrimaryFactor;
	float _VaSecondaryFactor;
	float _VaEdgeFlutter;
#endif
CBUFFER_END

#include "../../ShaderLibrary/Input.hlsl"
#include "../../ShaderLibrary/Core.hlsl"
#include "../../ShaderLibrary/SurfaceInput.hlsl"
#include "../../ShaderLibrary/PBDSkinning.hlsl"
#include "../../ShaderLibrary/PBDMesh.hlsl"
#include "../../ShaderLibrary/PBDGrass.hlsl"

//float4 MetallicSpecGloss(float2 uv, float albedoAlpha)
//{
//    float4 specGloss;
//
//    #ifdef _METALLICSPECGLOSSMAP
//        specGloss = SAMPLE_METALLICSPECULAR(uv);
//        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//            specGloss.a = albedoAlpha * _GlossMapScale;
//        #else
//            specGloss.a *= _GlossMapScale;
//        #endif
//
//    #else // _METALLICSPECGLOSSMAP
//        #if _SPECULAR_SETUP
//            specGloss.rgb = _SpecColor.rgb;
//        #else
//            specGloss.rgb = _Metallic.rrr;
//        #endif
//
//        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//            specGloss.a = albedoAlpha * _GlossMapScale;
//        #else
//            specGloss.a = _Glossiness;
//        #endif
//    #endif // _METALLICSPECGLOSSMAP
//
//    return specGloss;
//}

void RimLighting(float3 normalWS, float3 viewDirectionWS, inout SurfaceData outSurfaceData)
{
    float ndotv = dot(normalWS, viewDirectionWS);
    float rim = pow(saturate(1.0 - ndotv), _RimPower);
	rim *= rim * _RimColor.a;
    float3 rimColor = lerp(outSurfaceData.albedo, _RimColor.rgb, _RimColor.a);
        
    outSurfaceData.albedo = lerp(outSurfaceData.albedo, 0, rim);
    outSurfaceData.emission = lerp(outSurfaceData.emission, rimColor, rim);
    outSurfaceData.smoothness = lerp(outSurfaceData.smoothness, 0, rim);
    outSurfaceData.metallic = lerp(outSurfaceData.metallic, 0, rim);
};

void Dissolve(float2 uv, inout SurfaceData outSurfaceData)
{
	#ifdef DISSOLVE_ON
		#ifdef _DISSOLVE_NOISEMAP
			float2 noiseUv = TRANSFORM_TEX(uv, _DissolveNoiseMap);
			noiseUv = SAMPLE_TEXTURE2D(_DissolveNoiseMap, sampler_DissolveNoiseMap, noiseUv).rg;
			uv += noiseUv * _DissolveNoiseScale;
		#endif
		float dissolveMask = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, uv).r;
		float dissolve = _Dissolve;
		float dissolveBorder = dissolve + _DissolveWidth;
		float dissolveValue = dissolveMask > dissolve ? 1 : 0;
		clip(dissolveMask - dissolve * _DissolveCutout);
    
		float borderNorm = saturate((dissolveMask - dissolve) / _DissolveWidth);

		float gradient = dissolveValue * borderNorm;
		gradient = gradient < .001 ? 1 : gradient;
		float4 color = _DissolveColorScale * _DissolveColor;
		outSurfaceData.emission += (1 - gradient) * color.rgb * _DissolveEmission;
		outSurfaceData.albedo = lerp(color.rgb * (1 - _DissolveEmission), outSurfaceData.albedo.rgb, gradient);
	#endif
}

void AdditionalAlbedoMix(float2 uv, inout SurfaceData outSurfaceData)
{
	#if ADDITIONAL_ALBEDO
		float4 additionalAlbedo = SAMPLE_TEXTURE2D(_AdditionalAlbedoMap, sampler_AdditionalAlbedoMap, uv);
		float intensity = dot(outSurfaceData.albedo.rgb, float3(0.299, 0.587, 0.114));
		float maskIntensity = additionalAlbedo.a;
		float lerpFactor = saturate((maskIntensity - (1 - _AdditionalAlbedoFactor)) * _AdditionalAlbedoAlphaScale);
		float3 resultColor = clamp(intensity * additionalAlbedo.rgb * _AdditionalAlbedoColor.rgb * _AdditionalAlbedoColorScale, 0, _AdditionalAlbedoColorClamp);
		outSurfaceData.albedo.rgb = lerp(outSurfaceData.albedo.rgb, resultColor, lerpFactor);
	#endif
}

inline void InitializeStandardLitSurfaceData(float2 uv, float2 screenUv, out SurfaceData outSurfaceData)
{
    float4 albedoAlpha = SampleAlbedoAlpha(uv);
	if (_BaseColorBlending > 0)
	{
		albedoAlpha.rgb = lerp(_BaseColor.rgb, albedoAlpha.rgb, _BaseColor.a);
		_BaseColor.a = 1;
	}
	else
	{
		albedoAlpha.rgb *= _BaseColor.rgb;
	}

    #ifdef _MASKSMAP
        float4 masks = SAMPLE_TEXTURE2D(_MasksMap, sampler_MasksMap, uv);
    #else
        float4 masks = 1.0;
    #endif

    outSurfaceData.specular = float3(0.0, 0.0, 0.0);
    outSurfaceData.metallic = masks.b * _Metallic;
    // perceptual roughness to perceptual smoothness
    outSurfaceData.smoothness = 1.0 - (masks.r * _Roughness);
    float3 normal = SampleNormal(uv, _BumpScale);

    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.normalTS = normal;
    outSurfaceData.occlusion = 1.0;
    outSurfaceData.emission = SampleEmission(uv, albedoAlpha.rgb, _EmissionColor.rgb, masks.g, _EmissionColorScale, outSurfaceData.albedo);
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
	outSurfaceData.translucency = masks.a;
	outSurfaceData.wrapDiffuseFactor = _WrapDiffuseFactor;
}

#endif // OWLCAT_LIT_INPUT_INCLUDED
