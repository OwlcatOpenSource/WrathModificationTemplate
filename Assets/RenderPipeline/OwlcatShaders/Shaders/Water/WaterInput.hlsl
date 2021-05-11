#ifndef OWLCAT_WATER_INPUT_INCLUDED
#define OWLCAT_WATER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

#include "../../ShaderLibrary/Input.hlsl"
#include "../../ShaderLibrary/Core.hlsl"
#include "../../ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BumpMap_ST;
float4 _BumpMap_TexelSize;
float4 _BaseColor;
float _AlphaToCoverage;
float _Roughness;
float _Metallic;
float _BumpScale;
float4 _DoubleSidedConstants;

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

// Triple tap
float _TripleTapFreq;
float2 _HexRatio;

float _ShoreBlend;

float2 _FlowSpeed;
float _UvDirection;
float _Density;
float _FoamMaskScale;
float _FoamDepthPower;
float _FoamStrength;

float _WrapDiffuseFactor;
CBUFFER_END

TEXTURE2D(_FlowMap); SAMPLER(sampler_FlowMap);
TEXTURE2D(_FoamMap); SAMPLER(sampler_FoamMap);
TEXTURE2D(_FoamMaskMap); SAMPLER(sampler_FoamMaskMap);
TEXTURE2D(_FoamDensityRamp); SAMPLER(sampler_FoamDensityRamp);

#include "../../ShaderLibrary/DistortionUtils.hlsl"

struct TripleTapData
{
    float2x2 rot0;
    float2x2 rot1;
    float2x2 rot2;
    float3 hashAndWeight0;
    float3 hashAndWeight1;
    float3 hashAndWeight2;
    float2 vel0;
    float2 vel1;
    float2 vel2;
};

//credits for hex tiling goes to Shane (https://www.shadertoy.com/view/Xljczw)
//center, index
float4 GetHexGridInfo(float2 uv)
{
    float4 hexIndex = round(float4(uv, uv - float2(0.5, 1.0)) / _HexRatio.xyxy);
    float4 hexCenter = float4(hexIndex.xy * _HexRatio, (hexIndex.zw + 0.5) * _HexRatio);
    float4 offset = uv.xyxy - hexCenter;
    return dot(offset.xy, offset.xy) < dot(offset.zw, offset.zw) ? 
        float4(hexCenter.xy, hexIndex.xy) : 
        float4(hexCenter.zw, hexIndex.zw);
}

float GetHexSDF(in float2 p)
{
    p = abs(p);
    return 0.5 - max(dot(p, _HexRatio * 0.5), p.x);
}

//xy: node pos, z: weight
float3 GetTriangleInterpNode(in float2 pos, in float freq, in int nodeIndex)
{
    float2 nodeOffsets[3] = 
    {
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0,-1.0)
    };

    float2 uv = pos * freq + nodeOffsets[nodeIndex] / _HexRatio.xy * 0.5;
    float4 hexInfo = GetHexGridInfo(uv);
    float dist = GetHexSDF(uv - hexInfo.xy) * 2.0;
    return float3(hexInfo.xy / freq, dist);
}

// Hash without sine
//https://www.shadertoy.com/view/4djSRW
///  3 out, 3 in...
float3 hash33(float3 p3)
{
	p3 = frac(p3 * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return frac((p3.xxy + p3.yxx)*p3.zyx);
}

float3 hash33Old( float3 p )
{
	p = float3(dot(p,float3(127.1,311.7, 74.7)),
			  dot(p,float3(269.5,183.3,246.1)),
			  dot(p,float3(113.5,271.9,124.6)));

	return frac(sin(p)*43758.5453123);
}

float4 GetTextureSample(TEXTURE2D_PARAM(textureName, samplerName), float2 pos, float2 nodePoint)
{
    float3 hash = hash33(float3(nodePoint.xy, 0));
    float ang = hash.x * 2.0 * PI;
    float2x2 rotation = float2x2(cos(ang), sin(ang), -sin(ang), cos(ang));
    
    float2 uv = mul(rotation, pos) + hash.yz;
    return SAMPLE_TEXTURE2D(textureName, samplerName, uv);
}

void GetTap(float3 node, out float2x2 rot, out float3 hashAndWeight, out float2 vel)
{
	#if defined(_FLOWMAP)
		vel = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, node.xy).xy * 2.0 - 1.0;
	#else
		vel = normalize(_FlowSpeed);
	#endif

    float3 hash = hash33(float3(node.xy, 0));
    //float ang = hash.x * 2.0 * PI;
    //rot = float2x2(cos(ang), sin(ang), -sin(ang), cos(ang));
	float2 normVel = normalize(vel);

	// здесь зацикливаем UV на 1000 сек (~20 мин.), чтобы в UV не накапливались слишком больших значений
	// это приводит к неправильной фильтрации текстур
	// TODO: придумать алгоритм, при котором не будет зацикливаний или скачок между циклами будет незаметен
	vel = vel * _FlowSpeed.xy * (_Time.yy % 1000.0);

	float ang = 0;
	if (_UvDirection > 0)
	{
		ang = atan2(normVel.x, normVel.y);
	}
	else
	{
		ang = hash.x * 2.0 * PI;
	}

	float2 sinAndCos = 0;
	sincos(ang, sinAndCos.x, sinAndCos.y);
	rot = float2x2(sinAndCos.y, -sinAndCos.x, sinAndCos.x, sinAndCos.y);

    hashAndWeight = float3(hash.yz, node.z);
}

TripleTapData GetTripleTapData(float2 uv, float freq)
{
    TripleTapData result = (TripleTapData)0;

    float3 node = GetTriangleInterpNode(uv, freq, 0);
    GetTap(node, result.rot0, result.hashAndWeight0, result.vel0);

    node = GetTriangleInterpNode(uv, freq, 1);
    GetTap(node, result.rot1, result.hashAndWeight1, result.vel1);

    node = GetTriangleInterpNode(uv, freq, 2);
    GetTap(node, result.rot2, result.hashAndWeight2, result.vel2);

    return result;
}

float4 TripleTapSample(TEXTURE2D_PARAM(textureName, samplerName), float2 uv, TripleTapData tripleTap)
{
    float4 result = 0;
    //result += tripleTap.hashAndWeight0.z + tripleTap.hashAndWeight1.z + tripleTap.hashAndWeight2.z;
    //return result;
    float2 sampleUv = mul(tripleTap.rot0, uv + tripleTap.vel0) + tripleTap.hashAndWeight0.xy;
    result += SAMPLE_TEXTURE2D(textureName, samplerName, sampleUv) * tripleTap.hashAndWeight0.z;

    sampleUv = mul(tripleTap.rot1, uv + tripleTap.vel1) + tripleTap.hashAndWeight1.xy;
    result += SAMPLE_TEXTURE2D(textureName, samplerName, sampleUv) * tripleTap.hashAndWeight1.z;

    sampleUv = mul(tripleTap.rot2, uv + tripleTap.vel2) + tripleTap.hashAndWeight2.xy;
    result += SAMPLE_TEXTURE2D(textureName, samplerName, sampleUv) * tripleTap.hashAndWeight2.z;

    return result;
}

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

inline float4 InitializeStandardLitSurfaceData(float4 uv, float4 positionCS, out SurfaceData outSurfaceData)
{
    TripleTapData tripleTap = GetTripleTapData(uv.xy, _TripleTapFreq);

    #ifdef _NORMALMAP
        float4 n = TripleTapSample(_BumpMap, sampler_BumpMap, uv.zw, tripleTap);
        #if BUMP_SCALE_NOT_SUPPORTED
            float3 normal = UnpackNormal(n);
        #else
            float3 normal = UnpackNormalScale(n, _BumpScale);
        #endif
    #else
        float3 normal = float3(0,0,1);
    #endif

    float deviceDepth = LOAD_TEXTURE2D(_CameraDepthRT, positionCS.xy).x;
    float linearDepth = LinearEyeDepth(deviceDepth);
    float depthDiff = max(0, linearDepth - positionCS.w);
    float expDepthDiff = saturate(1 - exp2(-depthDiff * _Density));
    
    float shoreBlend = saturate(1.0 - exp(-_ShoreBlend * 10 * depthDiff));

    #ifdef FOAM_ON
        float4 foamSample = TripleTapSample(_FoamMap, sampler_FoamMap, uv.zw, tripleTap);
        float foamMask = SAMPLE_TEXTURE2D(_FoamMaskMap, sampler_FoamMaskMap, uv.xy).a * _FoamMaskScale;
        float shoreFoamMask = saturate(exp(-_FoamDepthPower * depthDiff)) * shoreBlend;
        foamMask = max(foamMask, shoreFoamMask);
        float4 foamRamp = SAMPLE_TEXTURE2D(_FoamDensityRamp, sampler_FoamDensityRamp, float2(foamMask, .5));
        float foam = saturate(dot(foamSample.rgb, foamRamp.rgb) * _FoamStrength);
    #else
        float foam = 0;
    #endif

    float4 albedoAlpha = _BaseColor;

    albedoAlpha.rgb = lerp(albedoAlpha.rgb, 1, foam);
    albedoAlpha.a = foam * shoreBlend;

    float4 masks = 1.0;

    outSurfaceData.specular = float3(0.0h, 0.0h, 0.0h);
    outSurfaceData.metallic = lerp(masks.b * _Metallic, 0, foam) * shoreBlend;
    // perceptual roughness to perceptual smoothness
    outSurfaceData.smoothness = lerp(1.0 - (masks.r * _Roughness), 0, foam) * shoreBlend;

    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.normalTS = normal;
    outSurfaceData.occlusion = 1.0;
    outSurfaceData.emission = 0;//SampleEmission(uv.xy, albedoAlpha.rgb, _EmissionColor.rgb, masks.g, _EmissionColorScale);
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, 0);
	outSurfaceData.translucency = masks.a;
    outSurfaceData.wrapDiffuseFactor = _WrapDiffuseFactor;

    
    _Distortion *= expDepthDiff;
    // _DistortionOffset - используется только в Particles.shader, поэтому здесь его зануляем
    _DistortionOffset = 0;
    float4 distortion = GetDistortion(positionCS.xy, outSurfaceData.normalTS, outSurfaceData.translucency.r, positionCS.w);

    depthDiff = distortion.a - positionCS.w;
    if (depthDiff >= 0)
    {
        expDepthDiff = saturate(1 - exp2(-depthDiff * _Density));
	}

    // modify alpha and albedo before distortion
    outSurfaceData.alpha = max(expDepthDiff, outSurfaceData.alpha);
    outSurfaceData.albedo *= outSurfaceData.alpha;

    return distortion;
}

inline void ModifySurfaceDataForDistortionBeforeLighting(inout SurfaceData surfaceData, float4 distortion, float waterLinearDepth, float sceneExpDepth)
{
    float depthDiff = distortion.a - waterLinearDepth;
    float expDepthDiff = sceneExpDepth;
    if (depthDiff >= 0)
    {
        expDepthDiff = saturate(1 - exp2(-depthDiff * _Density));
	}

    float alpha = max(expDepthDiff, surfaceData.alpha);

    surfaceData.albedo *= alpha;
    surfaceData.alpha = alpha;
}

#endif // OWLCAT_WATER_INPUT_INCLUDED