#ifndef OWLCAT_SHADOW_INCLUDED
#define OWLCAT_SHADOW_INCLUDED

#include "ShadowInput.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#if UNITY_REVERSED_Z
    #define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z <= UNITY_RAW_FAR_CLIP_VALUE
#else
    #define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z >= UNITY_RAW_FAR_CLIP_VALUE
#endif

float3 ApplyShadowBias(float3 positionWS, float3 normalWS, float3 lightDirection, float depthBias, float normalBias)
{
	float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
    float scale = invNdotL * normalBias;

    // normal bias is negative since we want to apply an inset normal offset
    positionWS = lightDirection * depthBias.xxx + positionWS;
    positionWS = normalWS * scale.xxx + positionWS;
    return positionWS;
}

float GetClipDistance(float2 clipPos, uint faceIndex, uint planeIndex)
{
    float3 coeffs = _Clips[faceIndex * 2 + planeIndex];
    return coeffs.x * clipPos.x + coeffs.y * clipPos.y + coeffs.z;
}

uint GetFaceIndex(float3 dir)
{
	float4x3 faceMatrix;
	faceMatrix[0] = _FaceVectors[0];
	faceMatrix[1] = _FaceVectors[1];
	faceMatrix[2] = _FaceVectors[2];
	faceMatrix[3] = _FaceVectors[3];
	float4 dotProducts = mul(faceMatrix, dir);
    float maximum = max(max(dotProducts.x, dotProducts.y), max(dotProducts.z, dotProducts.w));
    uint index;
    if (maximum == dotProducts.x)
        index = 0;
    else if (maximum == dotProducts.y)
        index = 1;
    else if (maximum == dotProducts.z)
        index = 2;
    else
        index = 3;
    return index;
}

float ComputeCascadeIndex(ShadowData sd, float3 positionWS)
{
    float3 fromCenter0 = positionWS.xyz - _ShadowMatricesBuffer[(int)sd.matrixIndices.x].spherePosition.xyz;
    float3 fromCenter1 = positionWS.xyz - _ShadowMatricesBuffer[(int)sd.matrixIndices.y].spherePosition.xyz;
    float3 fromCenter2 = positionWS.xyz - _ShadowMatricesBuffer[(int)sd.matrixIndices.z].spherePosition.xyz;
    float3 fromCenter3 = positionWS.xyz - _ShadowMatricesBuffer[(int)sd.matrixIndices.w].spherePosition.xyz;

    float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

    float4 radii = float4(_ShadowMatricesBuffer[sd.matrixIndices.x].sphereRadiusSq, _ShadowMatricesBuffer[sd.matrixIndices.y].sphereRadiusSq, _ShadowMatricesBuffer[sd.matrixIndices.z].sphereRadiusSq, _ShadowMatricesBuffer[sd.matrixIndices.w].sphereRadiusSq);
    float4 weights = float4(distances2 < radii);
    weights.yzw = saturate(weights.yzw - weights.xyz);

    return 4 - dot(weights, float4(4, 3, 2, 1));
}

float3 EvalShadow_GetTexcoords(float4x4 worldToShadow, float3 positionWS, float4 scaleOffset, bool perspProj)
{
    float4 posTC = mul(worldToShadow, float4(positionWS, 1.0));

    posTC.xyz = perspProj ? posTC.xyz /= posTC.w : posTC.xyz;
    posTC.xy = (posTC.xy * 0.5) + 0.5;
    posTC.y = (_ProjectionParams.x < 0) ? (1 - posTC.y) : posTC.y;
    posTC.xy = posTC.xy * scaleOffset.xy + scaleOffset.zw;
    return posTC.xyz;
}

float SampleShadow_PCF_1tap(float3 posTC)
{
    return SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, posTC.xyz);
}

float SampleShadow_PCF_Tent_3x3(float3 coord)
{
	float shadow = 0.0;
	float fetchesWeights[4];
	float2 fetchesUV[4];

	SampleShadow_ComputeSamples_Tent_3x3(_ShadowmapRT_TexelSize, coord.xy, fetchesWeights, fetchesUV);
	for (int i = 0; i < 4; i++)
	{
		shadow += fetchesWeights[i] * SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(fetchesUV[i].xy, coord.z));
	}
	return shadow;
}

float SampleShadow_PCF_Tent_5x5(float3 coord)
{
	float shadow = 0.0;
	float fetchesWeights[9];
	float2 fetchesUV[9];

	SampleShadow_ComputeSamples_Tent_5x5(_ShadowmapRT_TexelSize, coord.xy, fetchesWeights, fetchesUV);
	for (int i = 0; i < 9; i++)
	{
		shadow += fetchesWeights[i] * SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(fetchesUV[i].xy, coord.z));
	}
	return shadow;
}

float SampleShadow_PCF_Tent_7x7(float3 coord)
{
	float shadow = 0.0;
	float fetchesWeights[16];
	float2 fetchesUV[16];

	SampleShadow_ComputeSamples_Tent_7x7(_ShadowmapRT_TexelSize, coord.xy, fetchesWeights, fetchesUV);
	for (int i = 0; i < 16; i++)
	{
		shadow += fetchesWeights[i] * SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(fetchesUV[i].xy, coord.z));
	}
	return shadow;
}

float SampleShadow_PCF_9tap_Adaptive(float3 tcs)
{
    real filterSize = 1;

    float2 texelSizeRcp = _ShadowmapRT_TexelSize.xy * filterSize;

	// Terms0 are weights for the individual samples, the other terms are offsets in texel space
    float4 vShadow3x3PCFTerms0 = float4(20.0 / 267.0, 33.0 / 267.0, 55.0 / 267.0, 0.0);
    float4 vShadow3x3PCFTerms1 = float4(texelSizeRcp.x, texelSizeRcp.y, -texelSizeRcp.x, -texelSizeRcp.y);
    float4 vShadow3x3PCFTerms2 = float4(texelSizeRcp.x, texelSizeRcp.y, 0.0, 0.0);
    float4 vShadow3x3PCFTerms3 = float4(-texelSizeRcp.x, -texelSizeRcp.y, 0.0, 0.0);

    float4 v20Taps;
    v20Taps.x = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms1.xy, tcs.z)).x; //  1  1
    v20Taps.y = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms1.zy, tcs.z)).x; // -1  1
    v20Taps.z = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms1.xw, tcs.z)).x; //  1 -1
    v20Taps.w = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms1.zw, tcs.z)).x; // -1 -1
    float flSum = dot(v20Taps.xyzw, float4(0.25, 0.25, 0.25, 0.25));
	// fully in light or shadow? -> bail
    if ((flSum == 0.0) || (flSum == 1.0))
        return flSum;

	// we're in a transition area, do 5 more taps
    flSum *= vShadow3x3PCFTerms0.x * 4.0;

    float4 v33Taps;
    v33Taps.x = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms2.xz, tcs.z)).x; //  1  0
    v33Taps.y = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms3.xz, tcs.z)).x; // -1  0
    v33Taps.z = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms3.zy, tcs.z)).x; //  0 -1
    v33Taps.w = SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, float3(tcs.xy + vShadow3x3PCFTerms2.zy, tcs.z)).x; //  0  1
    flSum += dot(v33Taps.xyzw, vShadow3x3PCFTerms0.yyyy);

    flSum += SAMPLE_TEXTURE2D_SHADOW(_ShadowmapRT, sampler_ShadowmapRT, tcs).x * vShadow3x3PCFTerms0.z;

    return flSum;
}

float SampleShadow(float3 posTC, int algorithm)
{
    UNITY_BRANCH
	switch( algorithm )
	{
	case GPUSHADOWALGORITHM_PCF_1TAP		: return SampleShadow_PCF_1tap(posTC);
	case GPUSHADOWALGORITHM_PCF_9TAP		: return SampleShadow_PCF_9tap_Adaptive(posTC);
	case GPUSHADOWALGORITHM_PCF_TENT_3X3	: return SampleShadow_PCF_Tent_3x3(posTC);
	case GPUSHADOWALGORITHM_PCF_TENT_5X5	: return SampleShadow_PCF_Tent_5x5(posTC);
	case GPUSHADOWALGORITHM_PCF_TENT_7X7	: return SampleShadow_PCF_Tent_7x7(posTC);

	default: return 1.0;
	}
}

float SampleShadow(float3 posTC, bool softShadows)
{
    #ifdef SHADOWS_SOFT
        UNITY_BRANCH
        if (softShadows)
        {
            return SampleShadow_PCF_Tent_5x5(posTC);
        }
        else
        {
            return SampleShadow_PCF_1tap(posTC);
        }
    #elif SHADOWS_HARD
        return SampleShadow_PCF_1tap(posTC);
    #else
        return 1.0;
    #endif
}

float EvalPunctualShadow(int shadowIndex, float3 lightDirection, float3 positionWS)
{
    ShadowData sd = _ShadowDataBuffer[shadowIndex];
	bool pointLight = (sd.shadowFlags & 1 << 0) != 0;
    bool softShadows = (sd.shadowFlags & 1 << 1) != 0;
    float result = 1.0;

    uint faceIndex = 0;
    if (pointLight)
    {
        faceIndex = GetFaceIndex(-lightDirection);   
    }

    int matrixIndex = (int) (sd.matrixIndices[faceIndex]);
    float4x4 worldToShadow = _ShadowMatricesBuffer[matrixIndex].worldToShadow;
    float4 scaleOffset = sd.atlasScaleOffset;
    float3 posTC = EvalShadow_GetTexcoords(worldToShadow, positionWS, scaleOffset, true);
    
    //int algorithm = softShadows ? _ShadowCurrentAlgorithm : GPUSHADOWALGORITHM_PCF_1TAP;
    result = SampleShadow(posTC.xyz, softShadows);

    return result;
}

float EvalDirectionalShadow(int shadowIndex, float3 lightDirection, float3 positionWS)
{
    ShadowData sd = _ShadowDataBuffer[shadowIndex];
    bool softShadows = (sd.shadowFlags & 1 << 1) != 0;
    float result = 1.0;

    
    int cascadeIndex = ComputeCascadeIndex(sd, positionWS);
    int matrixIndex = (int) (sd.matrixIndices[cascadeIndex]);
    float4x4 worldToShadow = _ShadowMatricesBuffer[matrixIndex].worldToShadow;
    float4 scaleOffset = sd.atlasScaleOffset;

    float3 posTC = EvalShadow_GetTexcoords(worldToShadow, positionWS, scaleOffset, false);

    //int algorithm = softShadows ? _ShadowCurrentAlgorithm : GPUSHADOWALGORITHM_PCF_1TAP;
    result = SampleShadow(posTC.xyz, softShadows);

	// Shadow coords that fall out of the light frustum volume must always return attenuation 1.0
    return BEYOND_SHADOW_FAR(posTC) || cascadeIndex > 3 ? 1.0 : result;
}

#endif // OWLCAT_SHADOW_INCLUDED
