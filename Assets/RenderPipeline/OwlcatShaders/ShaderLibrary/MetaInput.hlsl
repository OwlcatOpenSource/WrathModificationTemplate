#ifndef OWLCAT_META_PASS_INCLUDED
#define OWLCAT_META_PASS_INCLUDED

#include "Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

CBUFFER_START(UnityMetaPass)
// x = use uv1 as raster position
// y = use uv2 as raster position
bool4 unity_MetaVertexControl;

// x = return albedo
// y = return normal
bool4 unity_MetaFragmentControl;
CBUFFER_END

float unity_OneOverOutputBoost;
float unity_MaxOutputValue;
float unity_UseLinearSpace;

struct MetaInput
{
	float3 Albedo;
	float3 Emission;
	float3 SpecularColor;
};

struct Attributes
{
	float4 positionOS   : POSITION;
	float3  normalOS     : NORMAL;
	float2 uv           : TEXCOORD0;
	float2 uvLM         : TEXCOORD1;
	float2 uvDLM        : TEXCOORD2;
#ifdef _TANGENT_TO_WORLD
	float4 tangentOS     : TANGENT;
#endif
};

struct Varyings
{
	float4 positionCS   : SV_POSITION;
	float2 uv           : TEXCOORD0;
};

float4 MetaVertexPosition(float4 positionOS, float2 uvLM, float2 uvDLM, float4 lightmapST, float4 dynamicLightmapST)
{
	if (unity_MetaVertexControl.x)
	{
		positionOS.xy = uvLM * lightmapST.xy + lightmapST.zw;

		// OpenGL right now needs to actually use incoming vertex position,
		// so use it in a very dummy way
		positionOS.z = positionOS.z > 0 ? REAL_MIN : 0.0f;
	}
	
	if (unity_MetaVertexControl.y)
	{
		positionOS.xy = uvDLM * dynamicLightmapST.xy + dynamicLightmapST.zw;

		// OpenGL right now needs to actually use incoming vertex position,
		// so use it in a very dummy way
		positionOS.z = positionOS.z > 0 ? REAL_MIN : 0.0f;
	}
	
	return TransformWorldToHClip(positionOS.xyz);
}

float4 MetaFragment(MetaInput input)
{
	float4 res = 0;
	if (unity_MetaFragmentControl.x)
	{
		res = float4(input.Albedo, 1.0);

		// d3d9 shader compiler doesn't like NaNs and infinity.
		unity_OneOverOutputBoost = saturate(unity_OneOverOutputBoost);

		// Apply Albedo Boost from LightmapSettings.
		res.rgb = clamp(PositivePow(res.rgb, unity_OneOverOutputBoost), 0, unity_MaxOutputValue);
	}
	if (unity_MetaFragmentControl.y)
	{
		float3 emission;
		if (unity_UseLinearSpace)
		{
			emission = input.Emission;
		}
		else
		{
			emission = SRGBToLinear(input.Emission);
		}

		res = float4(emission, 1.0);
	}

	return res;
}

#endif // OWLCAT_META_PASS_INCLUDED
