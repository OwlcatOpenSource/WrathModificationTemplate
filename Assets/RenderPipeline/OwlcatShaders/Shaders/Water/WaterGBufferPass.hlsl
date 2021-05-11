#ifndef OWLCAT_WATER_GBUFFER_PASS_INCLUDED
#define OWLCAT_WATER_GBUFFER_PASS_INCLUDED

#include "WaterInput.hlsl"
#include "../../ShaderLibrary/GPUSkinning.hlsl"
#include "../../Lighting/DeferredData.cs.hlsl"
#include "../../ShaderLibrary/GBufferUtils.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"

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
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 uv               : TEXCOORD0;
	float4 giSampling		: TEXCOORD1;
	float3 positionWS		: TEXCOORD2;
    float3 normalWS         : TEXCOORD3;
	#if defined(_NORMALMAP)
        float3 tangentWS    : TEXCOORD4;
        float3 bitangentWS	: TEXCOORD5;
	#endif
	float4 viewDir			: TEXCOORD6;
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

	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInput.positionCS;
	output.positionWS = vertexInput.positionWS;
	output.viewDir.xyz = _WorldSpaceCameraPos - output.positionWS;
    
    output.uv.xy = input.texcoord;

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #ifdef _NORMALMAP
		output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);
        output.normalWS = normalInput.normalWS;
        output.tangentWS = normalInput.tangentWS;
        output.bitangentWS = normalInput.bitangentWS;
    #else
        output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
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

	#if defined(PASS_SCENESELECTIONPASS)
		GBufferOutput output = (GBufferOutput)0;
		output.normal = float4(_ObjectId, _PassValue, 1.0, 1.0);
		return output;
	#endif

	SurfaceData surfaceData;
	InitializeStandardLitSurfaceData(input.uv, input.positionCS, surfaceData);

	#if defined(_NORMALMAP)
        float3 normalWS = TransformTangentToWorld(surfaceData.normalTS, float3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
    #else
        float3 normalWS = input.normalWS;
    #endif

	normalWS = normalize(normalWS);

	uint materialFeatures = MATERIALFEATURES_LIGHTING_ENABLED;
	#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
		materialFeatures |= MATERIALFEATURES_REFLECTIONS;
	#endif

	float3 bakedGI = 0;
	float4 shadowmask = 1;
    SampleGI(input.giSampling, input.positionWS, normalWS, /*out bakedGI*/ bakedGI.rgb, /*out shadowMask*/ shadowmask);

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

#endif // OWLCAT_WATER_GBUFFER_PASS_INCLUDED
