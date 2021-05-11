#ifndef OWLCAT_PARTICLES_INPUT_INCLUDED
#define OWLCAT_PARTICLES_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

TEXTURE2D(_MainTex1); SAMPLER(sampler_MainTex1);
TEXTURE2D(_ColorAlphaRamp); SAMPLER(sampler_ColorAlphaRamp);
TEXTURE2D(_Noise0Tex); SAMPLER(sampler_Noise0Tex);
TEXTURE2D(_Noise1Tex); SAMPLER(sampler_Noise1Tex);
TEXTURE2D(_FluidFogMask);

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseMap_TexelSize;
float4 _BaseMap_MipInfo;
float4 _BaseColor;
float4 _BumpMap_ST;
float _Cutoff;
float _AlphaToCoverage;
float _Roughness;
float _Metallic;
float _BumpScale;
float4 _EmissionColor;
float _EmissionColorFactor;
float _EmissionColorScale;
float _EmissionMapUsage;
float _EmissionAlbedoSuppression;
float4 _DoubleSidedConstants;

// distortion
float _DistortionThicknessScale;
float _Distortion;
float _DistortionColorFactor;
float _DistortionDoesNotUseAlpha;
float2 _DistortionOffset;

// translucency
float _Thickness;
float3 _TranslucencyColor;

// radial alpha
float _RadialAlphaGradientStart;
float _RadialAlphaGradientPower;
float _RadialAlphaSubstract;

// PF1 specific
float2 _UV0Speed;
float2 _UVBumpSpeed;
float _AlphaScale;
float _HdrColorScale;
float _HdrColorClamp;
float _VirtualOffset;
float _VirtualOffsetVertexPosition;
float _TexSheetEnabled;
float _ApplyTexSheetUvBump;
float _SubstractVertexAlpha;
float4 _MainTex1_ST;
float2 _UV1Speed;
float _ApplyTexSheetUvTex1;
float _Tex1MixMode;
float _MainTex1Weight;
float4 _ColorAlphaRamp_ST;
float _RampAlbedoWeight;
float _RampScrollSpeed;
float _RandomizeRampOffset;
float4 _FluidFogMask_ST;

float4 _EmissionMap_ST;
float2 _UvEmissionSpeed;
float _ApplyTexSheetUvEmission;

float4 _Noise0Tex_ST;
float _Noise0Scale;
float _Noise0IDSpeedScale;
float2 _Noise0Speed;
float _ApplyTexSheetUvNoise0;
float _RandomizeNoiseOffset;

float4 _Noise1Tex_ST;
float _Noise1Scale;
float _Noise1IDSpeedScale;
float2 _Noise1Speed;
float _ApplyTexSheetUvNoise1;

float _Softness;
float _SubstractSoftness;

float _OpacityFalloff;
float _SubstractFalloff;
float _FogInfluence;
float _FogOfWarMaterialFlag;
float _UseUnscaledTime;

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
	float _VatUseParticlesVaryings;
#endif
CBUFFER_END

#include "../../ShaderLibrary/Input.hlsl"
#include "../../ShaderLibrary/Core.hlsl"
#include "../../ShaderLibrary/SurfaceInput.hlsl"

#define TRANSFORM_TEX_SCROLL(tex, name, speed) ((tex.xy) * name##_ST.xy + name##_ST.zw) + speed.xy * GetTime().yy;

struct VaryingsUv
{
	float2 originalUv;
	float2 texSheetUv;
	float2 tex0Uv;
	#if defined(TEXTURE1_ON)
		float2 tex1Uv;
	#endif
	#if defined(_NORMALMAP)
		float2 bumpUv;
	#endif
	#if defined(NOISE0_ON)
		float2 noiseUv0;
	#endif
	#if defined(NOISE1_ON)
		float2 noiseUv1;
	#endif
	#if defined(_EMISSIONMAP) && defined(_EMISSION)
		float2 emissionUv;
	#endif
};

struct SurfaceUv
{
	float2 originalUv;
	float2 uv0;
	float2 uv1;
	float2 bumpUv;
	float alphaRampOffset;
	#if defined(FLUID_FOG)
		float2 fluidFogUv;
	#endif
	float2 emissionUv;
};

float4 GetTime()
{
	if (_UseUnscaledTime)
	{
		return _UnscaledTime;
	}
	else
	{
		return _Time;
	}
}

float4 SampleFxTexture(TEXTURE2D_PARAM(textureName, samplerName), float2 uv)
{
	float4 result = SAMPLE_TEXTURE2D(textureName, samplerName, uv);
	#if !defined(UNITY_COLORSPACE_GAMMA)
		result.rgb = LinearToSRGB(result.rgb);
	#endif

	return result;
}

inline VaryingsUv GetVaryingsUv(float4 uv, float particleID)
{
	VaryingsUv result = (VaryingsUv)0;

	result.texSheetUv = uv.xy;
	// В случае, если активирована текстурная анимация в ParticleSystem
	// ParticleMaterialController должен переключить uvChannelMask = UV0
	// И добавить UV2 в VertexStreams, чтобы была возможность восстановить оригинальные не анимированные UV
	result.originalUv = _TexSheetEnabled ? uv.zw : uv.xy;

	result.tex0Uv = TRANSFORM_TEX_SCROLL(result.texSheetUv, _BaseMap, _UV0Speed.xy);

	#if defined(TEXTURE1_ON)
		result.tex1Uv = _ApplyTexSheetUvTex1 > 0 ? result.texSheetUv : result.originalUv;
		result.tex1Uv = TRANSFORM_TEX_SCROLL(result.tex1Uv, _MainTex1, _UV1Speed);
	#endif

	#if defined(_NORMALMAP)
		result.bumpUv = _ApplyTexSheetUvBump > 0 ? result.texSheetUv : result.originalUv;
		result.bumpUv = TRANSFORM_TEX_SCROLL(result.bumpUv, _BumpMap, _UVBumpSpeed);
	#endif

	#if defined(NOISE0_ON)
		result.noiseUv0 = _ApplyTexSheetUvNoise0 > 0 ? result.texSheetUv : result.originalUv;
		result.noiseUv0 = TRANSFORM_TEX(result.noiseUv0, _Noise0Tex) + _Noise0Speed * GetTime().yy + lerp(result.texSheetUv.xx, particleID.xx, _RandomizeNoiseOffset) * _Noise0IDSpeedScale;
	#endif

	#if defined(NOISE1_ON)
		result.noiseUv1 = _ApplyTexSheetUvNoise1 > 0 ? result.texSheetUv : result.originalUv;
		result.noiseUv1 = TRANSFORM_TEX(result.noiseUv1, _Noise1Tex) + _Noise1Speed * GetTime().yy + lerp(result.texSheetUv.xx, particleID.xx, _RandomizeNoiseOffset) * _Noise1IDSpeedScale;
	#endif

	#if defined(_EMISSIONMAP) && defined(_EMISSION)
		result.emissionUv = _ApplyTexSheetUvEmission > 0 ? result.texSheetUv : result.originalUv;
		result.emissionUv = TRANSFORM_TEX_SCROLL(result.emissionUv, _EmissionMap, _UvEmissionSpeed);
	#endif

	return result;
}

inline float4 GetVertexOutputColor(float4 vertexColor)
{
	// Костыль из PF1
	#if !defined(UNITY_COLORSPACE_GAMMA)
		// цвет партиклов не нужно конвертировать,
		// но при этом должна быть выключена галка Apply Active Color Space в ParticleSystem.Renderer
		// тогда цвет всегда будет в гамме независимо от текущего Color Space проекта
		//input.color.rgb = LinearToSRGB(input.color.rgb);
		_BaseColor.rgb = LinearToSRGB(_BaseColor.rgb);
		//_HdrColorScale = LinearToSRGB(_HdrColorScale);
	#endif

	return vertexColor * _BaseColor;
}

inline SurfaceUv GetSurfaceUv(float4 uv0, float4 uv1, float alphaRampOffset, float4 noiseUv, float2 fluidFogUv, float2 emissionUv)
{
	SurfaceUv result = (SurfaceUv)0;

	result.originalUv = uv0.zw;

	#if (defined(NOISE_UV_CORRECTION) && (defined(NOISE0_ON) || defined(NOISE1_ON)))
		float2 uvCorrection = uv0.zw * 2.0 - 1.0;
		float noiseFade = saturate(1 - length(uvCorrection));
	#endif

	float2 noiseUv0 = 0;
	#if defined(NOISE0_ON)
		noiseUv0 = SampleFxTexture(TEXTURE2D_ARGS(_Noise0Tex, sampler_Noise0Tex), noiseUv.xy).rg * 2.0 - 1.0;
		#if defined(NOISE_UV_CORRECTION)
			_Noise0Scale *= noiseFade;
		#endif
		noiseUv0 *= _Noise0Scale;
	#endif

	float2 noiseUv1 = 0;
	#if defined(NOISE1_ON)
		noiseUv1 = SampleFxTexture(TEXTURE2D_ARGS(_Noise1Tex, sampler_Noise1Tex), noiseUv.zw).rg * 2.0 - 1.0;
		#if defined(NOISE_UV_CORRECTION)
			_Noise1Scale *= noiseFade;
		#endif
		noiseUv1 *= _Noise1Scale;
	#endif

	float2 uvNoised = noiseUv0 + noiseUv1;
	result.uv0 = uv0.xy + uvNoised;

	#if defined(TEXTURE1_ON)
		result.uv1 = uv1.xy + uvNoised;
	#endif

	#if defined(_NORMALMAP)
		result.bumpUv = uv1.zw + uvNoised;
	#endif

	#if defined(COLOR_ALPHA_RAMP)
		result.alphaRampOffset = alphaRampOffset;
	#endif

	#if defined(FLUID_FOG)
		result.fluidFogUv = fluidFogUv;
	#endif

	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		result.emissionUv = emissionUv + uvNoised;
	#endif

	return result;
}

inline float ParticlesAlpha(float2 uv, float albedoAlpha, float4 color, float cutoff, float softFactor, float opacityFalloffFactor)
{
	float alpha = albedoAlpha;

	if (_SubstractVertexAlpha > 0)
	{
		alpha = saturate(alpha - (1 - color.a));
	}
	else
	{
		alpha *= color.a;
	}

	#if defined(RADIAL_ALPHA)
		float radialGrad = saturate(pow(length(uv * 2.0 - 1.0), _RadialAlphaGradientPower));
		radialGrad = _RadialAlphaGradientStart * (1 - radialGrad);

		if (_RadialAlphaSubstract > 0)
		{
			alpha = alpha - (1 - saturate(radialGrad));
		}
		else
		{
			alpha = alpha * radialGrad;
		}
	#endif

	#if defined(SOFT_PARTICLES)
		if (_SubstractSoftness > 0)
		{
			alpha = saturate(alpha - (1 - softFactor));
		}
	#endif

	#if defined(OPACITY_FALLOFF)
		if (_SubstractFalloff > 0)
		{
			alpha = saturate(alpha - (1 - opacityFalloffFactor));
		}
	#endif

	alpha = saturate(alpha * _AlphaScale);

	#if defined(OPACITY_FALLOFF)
		if (_SubstractFalloff <= 0)
		{
			alpha *= opacityFalloffFactor;
		}
	#endif

	#if defined(_ALPHATEST_ON)
		clip(alpha - cutoff);
	#endif

    return alpha;
}

float4 MixTex1(float2 uv, float4 albedoAlpha)
{
	float4 tex1 = SampleFxTexture(TEXTURE2D_ARGS(_MainTex1, sampler_MainTex1), uv);
	tex1.rgb = tex1.rgb;
	if (_Tex1MixMode <= 1)
	{
		albedoAlpha = lerp(albedoAlpha, tex1, _MainTex1Weight);
	}
	else
	{
		albedoAlpha.rgb = lerp(albedoAlpha.rgb, tex1.rgb, _MainTex1Weight);
		albedoAlpha.a *= tex1.a;
	}

	return albedoAlpha;
}

float4 ApplyAlphaRamp(float alphaRampOffset, float4 albedoAlpha)
{
	float2 colorRampUv = float2(albedoAlpha.a * _ColorAlphaRamp_ST.x + _ColorAlphaRamp_ST.z, .5);
	colorRampUv.x += alphaRampOffset + _RampScrollSpeed * GetTime().y;
	float3 ramp = SampleFxTexture(TEXTURE2D_ARGS(_ColorAlphaRamp, sampler_ColorAlphaRamp), colorRampUv).rgb;
	albedoAlpha.rgb = lerp(ramp, ramp * albedoAlpha.rgb, _RampAlbedoWeight);
	return albedoAlpha;
}

inline void InitializeStandardLitSurfaceData(SurfaceUv uv, float4 vertexColor, float softFactor, float opacityFalloffFactor, out SurfaceData outSurfaceData)
{
	#if defined(FLUID_FOG)
		float4 albedoAlpha = SampleFxTexture(TEXTURE2D_ARGS(_FluidFogMask, s_linear_clamp_sampler), uv.fluidFogUv);
	#else
		float4 albedoAlpha = SampleFxTexture(TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap), uv.uv0);
	#endif

	#if defined(TEXTURE1_ON)
		albedoAlpha = MixTex1(uv.uv1, albedoAlpha);
	#endif

	#if defined(COLOR_ALPHA_RAMP)
		albedoAlpha = ApplyAlphaRamp(uv.alphaRampOffset, albedoAlpha);
	#endif

	albedoAlpha.rgb *= vertexColor.rgb;
	
	albedoAlpha.a = ParticlesAlpha(uv.originalUv, albedoAlpha.a, vertexColor, _Cutoff, softFactor, opacityFalloffFactor);

	float3 unscaledAlbedo = albedoAlpha.rgb;
	albedoAlpha *= float4(_HdrColorScale, _HdrColorScale, _HdrColorScale, 1);

	// правильный кламп с учетом пропорций каналов
	//float maxChannel = max(albedoAlpha.r, max(albedoAlpha.g, albedoAlpha.b));
	//float clampFactor = saturate(_HdrColorClamp / maxChannel);
	//albedoAlpha.rgb *= clampFactor;


	// Обратный костыль из PF1
	#if !defined(UNITY_COLORSPACE_GAMMA)
		albedoAlpha.rgb = SRGBToLinear(albedoAlpha.rgb);
		#if defined(_EMISSION) && !defined(_EMISSIONMAP)
			unscaledAlbedo.rgb = SRGBToLinear(unscaledAlbedo.rgb);
		#endif
	#endif

    #ifdef _MASKSMAP
        float4 masks = SAMPLE_TEXTURE2D(_MasksMap, sampler_MasksMap, uv.uv0);
    #else
        float4 masks = 1.0;
    #endif

    outSurfaceData.specular = float3(0.0h, 0.0h, 0.0h);
    outSurfaceData.metallic = masks.b * _Metallic;
    // perceptual roughness to perceptual smoothness
    outSurfaceData.smoothness = 1.0 - (masks.r * _Roughness);
    float3 normal = SampleNormal(uv.bumpUv, _BumpScale);

	outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.normalTS = normal;
    outSurfaceData.occlusion = 1.0;
    outSurfaceData.emission = SampleEmission(uv.emissionUv, unscaledAlbedo.rgb, _EmissionColor.rgb, masks.g, _EmissionColorScale, outSurfaceData.albedo);
    outSurfaceData.alpha = albedoAlpha.a;
	outSurfaceData.translucency = masks.a;
	outSurfaceData.wrapDiffuseFactor = _WrapDiffuseFactor;
}

#endif // OWLCAT_PARTICLES_INPUT_INCLUDED
