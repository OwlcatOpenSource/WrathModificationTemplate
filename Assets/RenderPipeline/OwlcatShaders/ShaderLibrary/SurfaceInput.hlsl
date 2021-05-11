#ifndef OWLCAT_INPUT_SURFACE_INCLUDED
#define OWLCAT_INPUT_SURFACE_INCLUDED

#include "Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

#ifdef _NORMALMAP
    TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
#endif

#ifdef _MASKSMAP
    TEXTURE2D(_MasksMap); SAMPLER(sampler_MasksMap);
#endif

#ifdef _EMISSIONMAP
    TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
#endif

#ifdef DISSOLVE_ON
	TEXTURE2D(_DissolveMap); SAMPLER(sampler_DissolveMap);

    #ifdef _DISSOLVE_NOISEMAP
	    TEXTURE2D(_DissolveNoiseMap); SAMPLER(sampler_DissolveNoiseMap);
    #endif
#endif

#ifdef ADDITIONAL_ALBEDO
	TEXTURE2D(_AdditionalAlbedoMap); SAMPLER(sampler_AdditionalAlbedoMap);
#endif

// Must match Lightweight ShaderGraph master node
struct SurfaceData
{
    float3 albedo;
    float3 specular;
    float metallic;
    float smoothness;
    float3 normalTS;
    float3 emission;
    float occlusion;
    float alpha;
	float3 translucency;
    float wrapDiffuseFactor;
};

///////////////////////////////////////////////////////////////////////////////
//                      Material Property Helpers                            //
///////////////////////////////////////////////////////////////////////////////
float Alpha(float albedoAlpha, float4 color, float cutoff)
{
	#if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) && !defined(_GLOSSINESS_FROM_BASE_ALPHA)
		float alpha = albedoAlpha * color.a;
	#else
		float alpha = color.a;
	#endif

	#if defined(_ALPHATEST_ON)
		clip(alpha - cutoff);
	#endif

    return alpha;
}

float4 SampleAlbedoAlpha(float2 uv)
{
    return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
}

float3 SampleNormal(float2 uv, float scale = 1.0)
{
#ifdef _NORMALMAP
    float4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(n);
    #else
        return UnpackNormalScale(n, scale);
    #endif
#else
    return float3(0.0, 0.0, 1.0);
#endif
}

float3 SampleEmission(float2 uv, float3 albedo, float3 emissionColor, float mask, float intensity, inout float3 albedoForSuppression)
{
    float3 emission = 0;
    #if defined(_EMISSION)

        emission = lerp(albedo, emissionColor, _EmissionColorFactor);

        #if defined(_EMISSIONMAP)
            float4 emissionSample = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv);
            if (_EmissionMapUsage > 0)
            {
                emission *= emissionSample.a;
                albedoForSuppression = lerp(albedoForSuppression, 0, saturate(_EmissionAlbedoSuppression * emissionSample.a));
			}
            else
            {
                emission *= emissionSample.rgb;
                albedoForSuppression = lerp(albedoForSuppression, 0, saturate(_EmissionAlbedoSuppression * dot(emissionSample.rgb, float3(.3, .59, .11))));
			}
        #else
            emission *= mask;
            albedoForSuppression = lerp(albedoForSuppression, 0, saturate(_EmissionAlbedoSuppression * mask));
        #endif
    #endif

    return emission * max(0, intensity);
}

#endif // OWLCAT_INPUT_SURFACE_INCLUDED
