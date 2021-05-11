#ifndef OWLCAT_TERRAIN_COMMON_INCLUDED
#define OWLCAT_TERRAIN_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

#if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
    #define ENABLE_TERRAIN_PERPIXEL_NORMAL
#endif

#ifdef UNITY_INSTANCING_ENABLED
    TEXTURE2D(_TerrainHeightmapTexture);
    TEXTURE2D(_TerrainNormalmapTexture);
    SAMPLER(sampler_TerrainNormalmapTexture);
    float4 _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
#endif

UNITY_INSTANCING_BUFFER_START(Terrain)
    UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData)  // float4(xBase, yBase, skipScale, ~)
UNITY_INSTANCING_BUFFER_END(Terrain)

struct MaxLayerWeights
{
    int index0;
    int index1;
    int index2;
    int index3;
    float weight0;
    float weight1;
    float weight2;
    float weight3;
};

// Поиск 4 максимальных весов для блендинга
MaxLayerWeights GetMaxWeights(float2 uv)
{
    MaxLayerWeights maxWeights;

    if (_ControlTexturesCount == 1)
    {
        float4 control0 = SAMPLE_TEXTURE2D_ARRAY(_SplatArray, sampler_SplatArray, uv, 0);
        maxWeights.index0 = 0;
        maxWeights.index1 = 1;
        maxWeights.index2 = 2;
        maxWeights.index3 = 3;
        maxWeights.weight0 = control0.r;
        maxWeights.weight1 = control0.g;
        maxWeights.weight2 = control0.b;
        maxWeights.weight3 = control0.a;
    }
    else
    {
        maxWeights.index0 = 0;
        maxWeights.index1 = 1;
        maxWeights.index2 = 2;
        maxWeights.index3 = 3;
        maxWeights.weight0 = 0;
        maxWeights.weight1 = 0;
        maxWeights.weight2 = 0;
        maxWeights.weight3 = 0;

        for (int i = 0; i < _ControlTexturesCount; i++)
        {
            float4 control = SAMPLE_TEXTURE2D_ARRAY(_SplatArray, sampler_SplatArray, uv, i);
            if (control.r > maxWeights.weight0)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = maxWeights.weight0;
                maxWeights.index1 = maxWeights.index0;

                maxWeights.weight0 = control.r;
                maxWeights.index0 = i * 4 + 0;
            }
            else if (control.r > maxWeights.weight1)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = control.r;
                maxWeights.index1 = i * 4 + 0;
            }
            else if (control.r > maxWeights.weight2)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = control.r;
                maxWeights.index2 = i * 4 + 0;
            }
            else if (control.r > maxWeights.weight3)
            {
                maxWeights.weight3 = control.r;
                maxWeights.index3 = i * 4 + 0;
            }

            if (control.g > maxWeights.weight0)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = maxWeights.weight0;
                maxWeights.index1 = maxWeights.index0;

                maxWeights.weight0 = control.g;
                maxWeights.index0 = i * 4 + 1;
            }
            else if (control.g > maxWeights.weight1)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = control.g;
                maxWeights.index1 = i * 4 + 1;
            }
            else if (control.g > maxWeights.weight2)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = control.g;
                maxWeights.index2 = i * 4 + 1;
            }
            else if (control.g > maxWeights.weight3)
            {
                maxWeights.weight3 = control.g;
                maxWeights.index3 = i * 4 + 1;
            }

            if (control.b > maxWeights.weight0)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = maxWeights.weight0;
                maxWeights.index1 = maxWeights.index0;

                maxWeights.weight0 = control.b;
                maxWeights.index0 = i * 4 + 2;
            }
            else if (control.b > maxWeights.weight1)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = control.b;
                maxWeights.index1 = i * 4 + 2;
            }
            else if (control.b > maxWeights.weight2)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = control.b;
                maxWeights.index2 = i * 4 + 2;
            }
            else if (control.b > maxWeights.weight3)
            {
                maxWeights.weight3 = control.b;
                maxWeights.index3 = i * 4 + 2;
            }

            if (control.a > maxWeights.weight0)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = maxWeights.weight0;
                maxWeights.index1 = maxWeights.index0;

                maxWeights.weight0 = control.a;
                maxWeights.index0 = i * 4 + 3;
            }
            else if (control.a > maxWeights.weight1)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = maxWeights.weight1;
                maxWeights.index2 = maxWeights.index1;

                maxWeights.weight1 = control.a;
                maxWeights.index1 = i * 4 + 3;
            }
            else if (control.a > maxWeights.weight2)
            {
                maxWeights.weight3 = maxWeights.weight2;
                maxWeights.index3 = maxWeights.index2;

                maxWeights.weight2 = control.a;
                maxWeights.index2 = i * 4 + 3;
            }
            else if (control.a > maxWeights.weight3)
            {
                maxWeights.weight3 = control.a;
                maxWeights.index3 = i * 4 + 3;
            }
        }
    }

    float norm = 1.0 / (maxWeights.weight0 + maxWeights.weight1 + maxWeights.weight2 + maxWeights.weight3);
    maxWeights.weight0 *= norm;
    maxWeights.weight1 *= norm;
    maxWeights.weight2 *= norm;
    maxWeights.weight3 *= norm;
    return maxWeights;
}

void TerrainInstancing(inout float4 vertex, inout float3 normal, inout float2 uv)
{
    #ifdef UNITY_INSTANCING_ENABLED
        float2 patchVertex = vertex.xy;
        float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

        float2 sampleCoords = (patchVertex.xy + instanceData.xy) * instanceData.z; // (xy + float2(xBase,yBase)) * skipScale
        float height = UnpackHeightmap(_TerrainHeightmapTexture.Load(int3(sampleCoords, 0)));

        vertex.xz = sampleCoords * _TerrainHeightmapScale.xz;
        vertex.y = height * _TerrainHeightmapScale.y;

        #ifdef ENABLE_TERRAIN_PERPIXEL_NORMAL
            normal = float3(0, 1, 0);
        #else
            normal = _TerrainNormalmapTexture.Load(int3(sampleCoords, 0)).rgb * 2 - 1;
        #endif
        uv = sampleCoords * _TerrainHeightmapRecipSize.zw;
    #endif
}

void TerrainInstancing(inout float4 vertex, inout float3 normal)
{
    float2 uv = { 0, 0 };
    TerrainInstancing(vertex, normal, uv);
}

void CalculateAlphaBlendParams(float4 splatControl, inout float4 layersAlpha)
{
	layersAlpha += HALF_MIN;
    layersAlpha *= splatControl;
    float maxChannel = max(max(layersAlpha.r, layersAlpha.g), max(layersAlpha.b, layersAlpha.a));
    layersAlpha = smoothstep(saturate(maxChannel - _AlphaBlendFactor), maxChannel, layersAlpha);
    float weight = dot(layersAlpha, 1.0) + HALF_MIN;
    layersAlpha /= weight;
}

// написано по статье http://untitledgam.es/2017/01/height-blending-shader/
// доработано так, чтобы блендить 4 слоя вместо 2-х
// в этой версии функции предрасчитаны коэффициенты
float4 AlphaBlend(float4 c0, float4 c1, float4 c2, float4 c3, float4 layersAlpha)
{
    return ((c0 * layersAlpha.r) + (c1 * layersAlpha.g) + (c2 * layersAlpha.b) + (c3 * layersAlpha.a));
}

// написано по статье http://untitledgam.es/2017/01/height-blending-shader/
// доработано так, чтобы блендить 4 слоя вместо 2-х
float4 AlphaBlend(float4 c0, float a0, float4 c1, float a1, float4 c2, float a2, float4 c3, float a3, float4 splatControl)
{
    float4 layersAlpha = float4(a0, a1, a2, a3);
    layersAlpha *= splatControl;
    float heightStart = max(max(layersAlpha.r, layersAlpha.g), max(layersAlpha.b, layersAlpha.a)) - _AlphaBlendFactor;
    layersAlpha.r = max(layersAlpha.r - heightStart, 0);
    layersAlpha.g = max(layersAlpha.g - heightStart, 0);
    layersAlpha.b = max(layersAlpha.b - heightStart, 0);
    layersAlpha.a = max(layersAlpha.a - heightStart, 0);
    float weight = dot(layersAlpha, 1.0);
    return ((c0 * layersAlpha.r) + (c1 * layersAlpha.g) + (c2 * layersAlpha.b) + (c3 * layersAlpha.a)) / weight;
}

float4 GetDefaultNormal()
{
    #if defined(UNITY_NO_DXT5nm)
        return float4(0.5h, 0.5h, 1.0h, 0.0h);
    #else
        return float4(0.5h, 0.5h, 0.0h, 1.0h);
    #endif
}

#ifndef TERRAIN_SPLAT_BASEPASS

struct TerrainMapping
{
	TerrainLayerData TerrainLayerData0;
	TerrainLayerData TerrainLayerData1;
	TerrainLayerData TerrainLayerData2;
	TerrainLayerData TerrainLayerData3;

	float2 uvXZ0;
	float2 uvXZ1;
	float2 uvXZ2;
	float2 uvXZ3;

	#ifdef _TRIPLANAR
		float2 uvXY0;
		float2 uvXY1;
		float2 uvXY2;
		float2 uvXY3;

		float2 uvZY0;
		float2 uvZY1;
		float2 uvZY2;
		float2 uvZY3;
	#endif

	float4 gradXZ0;
	float4 gradXZ1;
	float4 gradXZ2;
	float4 gradXZ3;

	#ifdef _TRIPLANAR
		float4 gradXY0;
		float4 gradXY1;
		float4 gradXY2;
		float4 gradXY3;

		float4 gradZY0;
		float4 gradZY1;
		float4 gradZY2;
		float4 gradZY3;

		float3 triplanarWeights;
	#endif
};

TerrainMapping GetTerrainMapping(MaxLayerWeights weights, float2 uv, float3 normalWS, float3 positionOS)
{
	TerrainMapping output = (TerrainMapping)0;
	output.TerrainLayerData0 = _TerrainLayerDatas[weights.index0];
	output.TerrainLayerData1 = _TerrainLayerDatas[weights.index1];
	output.TerrainLayerData2 = _TerrainLayerDatas[weights.index2];
	output.TerrainLayerData3 = _TerrainLayerDatas[weights.index3];

	float2x2 rot0 = float2x2(output.TerrainLayerData0.uvMatrix.xy, output.TerrainLayerData0.uvMatrix.zw);
    float2x2 rot1 = float2x2(output.TerrainLayerData1.uvMatrix.xy, output.TerrainLayerData1.uvMatrix.zw);
    float2x2 rot2 = float2x2(output.TerrainLayerData2.uvMatrix.xy, output.TerrainLayerData2.uvMatrix.zw);
    float2x2 rot3 = float2x2(output.TerrainLayerData3.uvMatrix.xy, output.TerrainLayerData3.uvMatrix.zw);

	float4 dduvXZ = float4(ddx(uv.xy), ddy(uv.xy));

	output.uvXZ0 = mul(rot0, uv);
	output.uvXZ1 = mul(rot1, uv);
	output.uvXZ2 = mul(rot2, uv);
	output.uvXZ3 = mul(rot3, uv);

	output.gradXZ0 = dduvXZ * output.TerrainLayerData0.uvScale;
	output.gradXZ1 = dduvXZ * output.TerrainLayerData1.uvScale;
	output.gradXZ2 = dduvXZ * output.TerrainLayerData2.uvScale;
	output.gradXZ3 = dduvXZ * output.TerrainLayerData3.uvScale;

	#ifdef _TRIPLANAR
		float3 absVertexNormal = abs(normalWS);
        output.triplanarWeights = saturate(absVertexNormal - (float3) _TriplanarTightenFactor);
        output.triplanarWeights /= (dot(output.triplanarWeights, 1) + HALF_MIN);
        float3 triplanarUVW = positionOS * _TerrainMaxHeight;
        triplanarUVW.xz = uv.xy;

		output.uvXY0 = mul(rot0, triplanarUVW.xy);
        output.uvXY1 = mul(rot1, triplanarUVW.xy);
        output.uvXY2 = mul(rot2, triplanarUVW.xy);
        output.uvXY3 = mul(rot3, triplanarUVW.xy);

        output.uvZY0 = mul(rot0, triplanarUVW.zy);
        output.uvZY1 = mul(rot1, triplanarUVW.zy);
        output.uvZY2 = mul(rot2, triplanarUVW.zy);
        output.uvZY3 = mul(rot3, triplanarUVW.zy);

		float4 dduvXY = float4(ddx(triplanarUVW.xy), ddy(triplanarUVW.xy));
		output.gradXY0 = dduvXY * output.TerrainLayerData0.uvScale;
		output.gradXY1 = dduvXY * output.TerrainLayerData1.uvScale;
		output.gradXY2 = dduvXY * output.TerrainLayerData2.uvScale;
		output.gradXY3 = dduvXY * output.TerrainLayerData3.uvScale;

		float4 dduvZY = float4(ddx(triplanarUVW.zy), ddy(triplanarUVW.zy));
		output.gradZY0 = dduvZY * output.TerrainLayerData0.uvScale;
		output.gradZY1 = dduvZY * output.TerrainLayerData1.uvScale;
		output.gradZY2 = dduvZY * output.TerrainLayerData2.uvScale;
		output.gradZY3 = dduvZY * output.TerrainLayerData3.uvScale;
	#endif

	return output;
}

struct Splat
{
	float4 splatXZ0;
	float4 splatXZ1;
	float4 splatXZ2;
	float4 splatXZ3;

	#ifdef _TRIPLANAR
		float4 splatXY0;
		float4 splatXY1;
		float4 splatXY2;
		float4 splatXY3;

		float4 splatZY0;
		float4 splatZY1;
		float4 splatZY2;
		float4 splatZY3;
	#endif
};

Splat SplatFetch(TEXTURE2D_ARRAY_PARAM(tex, samplerName), TerrainMapping mapping, int4 texIndices)
{
	Splat splat = (Splat)0;

	#ifdef _TRIPLANAR
	if (mapping.triplanarWeights.y > 0)
	#endif
	{
		if (texIndices.x > -1)
		{
			splat.splatXZ0 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXZ0, texIndices.x, mapping.gradXZ0.xy, mapping.gradXZ0.zw);
		}
		if (texIndices.y > -1)
		{
			splat.splatXZ1 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXZ1, texIndices.y, mapping.gradXZ1.xy, mapping.gradXZ1.zw);
		}
		if (texIndices.z > -1)
		{
			splat.splatXZ2 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXZ2, texIndices.z, mapping.gradXZ2.xy, mapping.gradXZ2.zw);
		}
		if (texIndices.w > -1)
		{
			splat.splatXZ3 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXZ3, texIndices.w, mapping.gradXZ3.xy, mapping.gradXZ3.zw);
		}
	}

	#ifdef _TRIPLANAR
		if (mapping.triplanarWeights.z > 0)
        {
			if (texIndices.x > -1)
			{
				splat.splatXY0 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXY0, texIndices.x, mapping.gradXY0.xy, mapping.gradXY0.zw);
			}
			if (texIndices.y > -1)
			{
				splat.splatXY1 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXY1, texIndices.y, mapping.gradXY1.xy, mapping.gradXY1.zw);
			}
			if (texIndices.z > -1)
			{
				splat.splatXY2 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXY2, texIndices.z, mapping.gradXY2.xy, mapping.gradXY2.zw);
			}
			if (texIndices.w > -1)
			{
				splat.splatXY3 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvXY3, texIndices.w, mapping.gradXY3.xy, mapping.gradXY3.zw);
			}
        }

        if (mapping.triplanarWeights.x > 0)
        {
			if (texIndices.x > -1)
			{
				splat.splatZY0 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvZY0, texIndices.x, mapping.gradZY0.xy, mapping.gradZY0.zw);
			}
			if (texIndices.y > -1)
			{
				splat.splatZY1 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvZY1, texIndices.y, mapping.gradZY0.xy, mapping.gradZY0.zw);
			}
			if (texIndices.z > -1)
			{
				splat.splatZY2 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvZY2, texIndices.z, mapping.gradZY0.xy, mapping.gradZY0.zw);
			}
			if (texIndices.w > -1)
			{
				splat.splatZY3 = SAMPLE_TEXTURE2D_ARRAY_GRAD(tex, samplerName, mapping.uvZY3, texIndices.w, mapping.gradZY0.xy, mapping.gradZY0.zw);
			}
        }
	#endif

	return splat;
}

float4 SplatFetchDiffuse(TerrainMapping mapping, MaxLayerWeights weights, out float4 layersAlpha)
{
	Splat splat = SplatFetch(
		TEXTURE2D_ARRAY_ARGS(_DiffuseArray, sampler_DiffuseArray),
		mapping,
		int4(mapping.TerrainLayerData0.diffuseTexIndex, mapping.TerrainLayerData1.diffuseTexIndex, mapping.TerrainLayerData2.diffuseTexIndex, mapping.TerrainLayerData3.diffuseTexIndex));

	#ifdef _TRIPLANAR
		splat.splatXZ0 *= mapping.triplanarWeights.y;
		splat.splatXZ1 *= mapping.triplanarWeights.y;
		splat.splatXZ2 *= mapping.triplanarWeights.y;
		splat.splatXZ3 *= mapping.triplanarWeights.y;

		splat.splatXZ0 += splat.splatXY0 * mapping.triplanarWeights.z;
		splat.splatXZ1 += splat.splatXY1 * mapping.triplanarWeights.z;
		splat.splatXZ2 += splat.splatXY2 * mapping.triplanarWeights.z;
		splat.splatXZ3 += splat.splatXY3 * mapping.triplanarWeights.z;

		splat.splatXZ0 += splat.splatZY0 * mapping.triplanarWeights.x;
		splat.splatXZ1 += splat.splatZY1 * mapping.triplanarWeights.x;
		splat.splatXZ2 += splat.splatZY2 * mapping.triplanarWeights.x;
		splat.splatXZ3 += splat.splatZY3 * mapping.triplanarWeights.x;
	#endif

	float4 splatControl = float4(weights.weight0, weights.weight1, weights.weight2, weights.weight3);
	// Normalize weights before lighting and restore weights in final modifier functions so that the overal
    // lighting result can be correctly weighted.
    splatControl /= (dot(splatControl, 1.0) + HALF_MIN);

	layersAlpha = float4(splat.splatXZ0.a, splat.splatXZ1.a, splat.splatXZ2.a, splat.splatXZ3.a);
    CalculateAlphaBlendParams(splatControl, layersAlpha);

	#ifdef DEBUG_DISPLAY
		if (_DebugMipMap > 0)
		{
			splat.splatXZ0.rgb = GetMipMapDebug(mapping.uvXZ0, _DiffuseArray_TexelSize.zw, splat.splatXZ0.rgb);
			splat.splatXZ1.rgb = GetMipMapDebug(mapping.uvXZ1, _DiffuseArray_TexelSize.zw, splat.splatXZ1.rgb);
			splat.splatXZ2.rgb = GetMipMapDebug(mapping.uvXZ2, _DiffuseArray_TexelSize.zw, splat.splatXZ2.rgb);
			splat.splatXZ3.rgb = GetMipMapDebug(mapping.uvXZ3, _DiffuseArray_TexelSize.zw, splat.splatXZ3.rgb);
		}
	#endif

    return AlphaBlend(splat.splatXZ0, splat.splatXZ1, splat.splatXZ2, splat.splatXZ3, layersAlpha);
}

float4 SplatFetchMasks(TerrainMapping mapping, MaxLayerWeights weights, float4 layersAlpha)
{
	Splat splat = SplatFetch(
		TEXTURE2D_ARRAY_ARGS(_MasksArray, sampler_MasksArray),
		mapping,
		int4(mapping.TerrainLayerData0.masksTexIndex, mapping.TerrainLayerData1.masksTexIndex, mapping.TerrainLayerData2.masksTexIndex, mapping.TerrainLayerData3.masksTexIndex));

	#ifdef _TRIPLANAR
		splat.splatXZ0 *= mapping.triplanarWeights.y;
		splat.splatXZ1 *= mapping.triplanarWeights.y;
		splat.splatXZ2 *= mapping.triplanarWeights.y;
		splat.splatXZ3 *= mapping.triplanarWeights.y;

		splat.splatXZ0 += splat.splatXY0 * mapping.triplanarWeights.z;
		splat.splatXZ1 += splat.splatXY1 * mapping.triplanarWeights.z;
		splat.splatXZ2 += splat.splatXY2 * mapping.triplanarWeights.z;
		splat.splatXZ3 += splat.splatXY3 * mapping.triplanarWeights.z;

		splat.splatXZ0 += splat.splatZY0 * mapping.triplanarWeights.x;
		splat.splatXZ1 += splat.splatZY1 * mapping.triplanarWeights.x;
		splat.splatXZ2 += splat.splatZY2 * mapping.triplanarWeights.x;
		splat.splatXZ3 += splat.splatZY3 * mapping.triplanarWeights.x;
	#endif

	splat.splatXZ0 *= mapping.TerrainLayerData0.masksScale;
    splat.splatXZ1 *= mapping.TerrainLayerData1.masksScale;
    splat.splatXZ2 *= mapping.TerrainLayerData2.masksScale;
    splat.splatXZ3 *= mapping.TerrainLayerData3.masksScale;

	return AlphaBlend(splat.splatXZ0, splat.splatXZ1, splat.splatXZ2, splat.splatXZ3, layersAlpha);
}

float3 SplatFetchNormal(TerrainMapping mapping, MaxLayerWeights weights, float3 normalWS, float3 tangentWS, float3 bitangentWS, float2 uv, float4 layersAlpha)
{
	Splat splat = SplatFetch(
		TEXTURE2D_ARRAY_ARGS(_NormalArray, sampler_NormalArray),
		mapping,
		int4(mapping.TerrainLayerData0.normalTexIndex, mapping.TerrainLayerData1.normalTexIndex, mapping.TerrainLayerData2.normalTexIndex, mapping.TerrainLayerData3.normalTexIndex));

	if (mapping.TerrainLayerData0.normalTexIndex <= -1)
	{
		splat.splatXZ0 = GetDefaultNormal();
	}
	if (mapping.TerrainLayerData1.normalTexIndex <= -1)
	{
		splat.splatXZ1 = GetDefaultNormal();
	}
	if (mapping.TerrainLayerData2.normalTexIndex <= -1)
	{
		splat.splatXZ2 = GetDefaultNormal();
	}
	if (mapping.TerrainLayerData3.normalTexIndex <= -1)
	{
		splat.splatXZ3 = GetDefaultNormal();
	}

	float4 blendedNormal = AlphaBlend(splat.splatXZ0, splat.splatXZ1, splat.splatXZ2, splat.splatXZ3, layersAlpha);
	float3 normalY = UnpackNormal(blendedNormal);

	#ifdef _TRIPLANAR
		if (mapping.TerrainLayerData0.normalTexIndex <= -1)
		{
			splat.splatXY0 = GetDefaultNormal();
			splat.splatZY0 = GetDefaultNormal();
		}
		if (mapping.TerrainLayerData1.normalTexIndex <= -1)
		{
			splat.splatXY1 = GetDefaultNormal();
			splat.splatZY1 = GetDefaultNormal();
		}
		if (mapping.TerrainLayerData2.normalTexIndex <= -1)
		{
			splat.splatXY2 = GetDefaultNormal();
			splat.splatZY2 = GetDefaultNormal();
		}
		if (mapping.TerrainLayerData3.normalTexIndex <= -1)
		{
			splat.splatXY3 = GetDefaultNormal();
			splat.splatZY3 = GetDefaultNormal();
		}

		blendedNormal = AlphaBlend(splat.splatXY0, splat.splatXY1, splat.splatXY2, splat.splatXY3, layersAlpha);
		float3 normalZ = UnpackNormal(blendedNormal);
		blendedNormal = AlphaBlend(splat.splatZY0, splat.splatZY1, splat.splatZY2, splat.splatZY3, layersAlpha);
		float3 normalX = UnpackNormal(blendedNormal);

		// The Basic Swizzle
        // https://medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a
        // minor optimization of sign(). prevents return value of 0
        float3 axisSign = normalWS < 0 ? -1 : 1;
        // Get the sign (-1 or 1) of the surface normal
        //float3 axisSign = sign(normalWS);
            
        // Flip tangent normal z to account for surface normal facing
        normalX.z *= axisSign.x;
        normalY.z *= axisSign.y;
        normalZ.z *= axisSign.z;

        // Swizzle tangent normals to match world orientation and triblend
        normalWS =	normalX.zyx * mapping.triplanarWeights.x +
							normalY.xzy * mapping.triplanarWeights.y +
							normalZ.xyz * mapping.triplanarWeights.z;
	#else
		// NOTE: одна и та же текстура нормалей выглядит по-разному на обычной геометрии (Lit.shader) и на террэйне,
		// поэтому методом тыка определил, что нужно инвертировать ось X.
        normalY.x = -normalY.x;
        normalWS = TransformTangentToWorld(normalY, float3x3(tangentWS, bitangentWS, normalWS));
	#endif

	return normalWS;
}

void SplatmapMix(float2 uv, float3 positionOS, float3 vertexNormalWS, out float4 mixedDiffuse, out float4 mixedMasks)
{
    MaxLayerWeights weights = GetMaxWeights(uv.xy);
	TerrainMapping mapping = GetTerrainMapping(weights, uv.xy, vertexNormalWS, positionOS);

	float4 layersAlpha = 0;
	mixedDiffuse = SplatFetchDiffuse(mapping, weights, layersAlpha);
	mixedMasks = SplatFetchMasks(mapping, weights, layersAlpha);

    #ifdef DEBUG_DISPLAY
        if (DEBUGTERRAIN_WEIGHTS == _DebugTerrain)
        {
            mixedDiffuse = float4(weights.weight0, weights.weight1, weights.weight2, weights.weight3);
        }
        else if (DEBUGTERRAIN_INDICES == _DebugTerrain)
        {
            mixedDiffuse = float4(weights.index0, weights.index1, weights.index2, weights.index3) / 255;
        }
        #ifdef _TRIPLANAR
        else if (DEBUGTERRAIN_TRIPLANAR_PROJECTIONS == _DebugTerrain)
        {
            float4 result = float4(0, 0, 0, 1);
            if (mapping.triplanarWeights.x > 0)
            {
                result += float4(1, 0, 0, 0);
            }
            if (mapping.triplanarWeights.y > 0)
            {
                result += float4(0, 1, 0, 0);
            }
            if (mapping.triplanarWeights.z > 0)
            {
                result += float4(0, 0, 1, 0);
            }
            mixedDiffuse *= result;
        }
        #endif
    #endif
}

#endif
#endif // OWLCAT_TERRAIN_COMMON_INCLUDED
