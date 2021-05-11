#ifndef OWLCAT_DISTORTION_UTILS_CORE_INCLUDED
#define OWLCAT_DISTORTION_UTILS_CORE_INCLUDED

void EncodeDistortion(float2 distortion, float distortionBlur, float alpha, out float4 outBuffer)
{
	// RT - 16:16:16:16 float
    // distortionBlur in alpha for a different blend mode
	#if defined(DISTORTION_ON)
		if (_DistortionDoesNotUseAlpha > 0)
		{
			alpha = 1 - alpha;	
		}
		else
		{
		}
	#endif

    outBuffer = float4(distortion * alpha, 1, distortionBlur * alpha); // Caution: Blend mode depends on order of attribut here, can't change without updating blend mode.
}

void DecodeDistortion(float4 inBuffer, out float2 distortion, out float distortionBlur, out bool isSourceValid)
{
	distortion = inBuffer.xy;
	isSourceValid = inBuffer.z != 0;
    distortionBlur = inBuffer.a;
}

float4 GetDistortion(float2 screenUv, float3 normalTS, float translucencyMask, float depth)
{
	#if defined(DISTORTION_ON) && !defined(_TRANSPARENT_ON)
		float mip = _ColorPyramidLodCount * (1 - translucencyMask * _DistortionThicknessScale);
		float2 distortion = -normalTS.xy * _Distortion + _DistortionOffset.xy;
		// align texels (https://catlikecoding.com/unity/tutorials/flow/looking-through-water/)
		distortion = (floor(distortion * _ScreenSize.xy) + 0.5) * _ScreenSize.zw;

		// foreground objects distortion guard
		float sceneDepth = SampleDepthTexture(screenUv * _ScreenSize.zw + distortion);
		
		float4 result = LinearEyeDepth(sceneDepth);

		if (result.a <= depth)
		{
			distortion = 0;
		}

		result.rgb = SAMPLE_TEXTURE2D_LOD(_CameraColorPyramidRT, s_trilinear_clamp_sampler, screenUv * _ScreenSize.zw + distortion, mip).rgb;
		#if !defined(UNITY_COLORSPACE_GAMMA)
			result.rgb = SRGBToLinear(result.rgb);
		#endif
		return result;
	#else
		return 0;
	#endif
}

void ModifyAlbedoForDistortionBeforeLighting(inout float3 albedo, inout float alpha)
{
	#if defined(DISTORTION_ON)
		if (_DistortionDoesNotUseAlpha > 0)
		{
			albedo *= alpha;
		}
		else
		{
			albedo *= (1 - _DistortionColorFactor);
		}

		#if  defined(_TRANSPARENT_ON)
			alpha *= (1 - _DistortionColorFactor);
		#endif
	#endif
}

void ApplyDistortion(float3 distortion, inout float3 albedo, float alpha)
{
	#if defined(DISTORTION_ON)
		if (_DistortionDoesNotUseAlpha > 0)
		{
			albedo += distortion * (1 - alpha);
		}
		else
		{
			albedo += distortion * alpha * _DistortionColorFactor;
		}
	#endif
}

void ApplyDistortion(float2 screenUv, float3 normalTS, float translucencyMask, float depth, inout float3 albedo, float alpha)
{
	#if defined(DISTORTION_ON) && !defined(_TRANSPARENT_ON)
		float3 distortion = GetDistortion(screenUv, normalTS, translucencyMask, depth).rgb;
		ApplyDistortion(distortion.rgb, albedo, alpha);
	#endif
}
#endif // OWLCAT_DISTORTION_UTILS_CORE_INCLUDED
