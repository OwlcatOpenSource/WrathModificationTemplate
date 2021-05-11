#ifndef OWLCAT_WATER_FORWARD_PASS_INCLUDED
#define OWLCAT_WATER_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "WaterInput.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/GPUSkinning.hlsl"

struct Attributes
{
    float4 positionOS           : POSITION;
    float3 normalOS             : NORMAL;
    float4 tangentOS            : TANGENT;
    float2 texcoord             : TEXCOORD0;
    float2 lightmapUV           : TEXCOORD1;
	#ifdef DYNAMICLIGHTMAP_ON
		float2 dynamicLightmapUv: TEXCOORD2;
	#endif
    #ifdef _GPU_SKINNING
        float4 blendWeights     : BLENDWEIGHTS0;
        uint4 blendIndices      : BLENDINDICES0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS           : SV_POSITION;
    float4 uv                   : TEXCOORD0;
    float4 giSampling           : TEXCOORD1;
    float3 positionWS           : TEXCOORD2;
    float3 positionVS           : TEXCOORD3;
    float3 normalWS				: TEXCOORD4;
    #if defined(_NORMALMAP)
        float3 tangentWS		: TEXCOORD5;
        float3 bitangentWS		: TEXCOORD6;
    #endif
    float4 viewDir				: TEXCOORD7;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

void InitializeInputData(Varyings input, float3 normalTS, out InputData inputData)
{
    inputData.positionWS = input.positionWS.xyz;
    inputData.positionSS = input.positionCS.xy;
    inputData.linearDepth = input.positionCS.w;

	#ifdef _TRANSPARENT_ON
		#ifdef _NORMALMAP
			inputData.normalWS = TransformTangentToWorld(normalTS, float3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
		#else
			inputData.normalWS = input.normalWS;
		#endif
	#else
		// нормали читаем из GBuffer`а
		inputData.normalWS = DecodeNormal(LOAD_TEXTURE2D(_CameraNormalsRT, inputData.positionSS.xy).rgb);
	#endif

	inputData.normalWS = normalize(inputData.normalWS);

    inputData.viewDirectionWS = normalize(input.viewDir.xyz);

    inputData.fogCoord = ComputeFogFactor(LinearEyeDepth(input.positionCS.z));

	#ifdef _TRANSPARENT_ON
		SampleGI(input.giSampling, inputData.positionWS, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
	#else
		// Запеченное освещение читаем из GBuffer'а
		inputData.bakedGI = LOAD_TEXTURE2D(_CameraBakedGIRT, inputData.positionSS.xy).rgb;
		inputData.shadowMask = LOAD_TEXTURE2D(_CameraShadowmaskRT, inputData.positionSS.xy);
	#endif

    float depth = LinearViewDepth(input.positionVS, input.positionCS);

	inputData.depthSliceIndex = depth * _Clusters.z;
	inputData.clusterUv = uint3(inputData.positionSS * _ScreenSize.zw * _Clusters.xy, inputData.depthSliceIndex);
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

Varyings ForwardLitVertex(Attributes input)
{
    Varyings output = (Varyings) 0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    #ifdef _GPU_SKINNING
        input.positionOS.xyz = Skin(input.positionOS.xyz, input.blendWeights, input.blendIndices);
    #endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv.xy = input.texcoord;

    output.positionWS = vertexInput.positionWS;
    output.positionVS = vertexInput.positionVS;
    output.positionCS = vertexInput.positionCS;
    output.viewDir.xyz = _WorldSpaceCameraPos - output.positionWS;

    #ifdef _NORMALMAP
		output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);
        output.normalWS = normalInput.normalWS;
        output.tangentWS = normalInput.tangentWS;
        output.bitangentWS = normalInput.bitangentWS;
    #else
        output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    #endif

    // We either sample GI from lightmap or SH. lightmap UV and vertex SH coefficients
    // are packed in lightmapUVOrVertexSH to save interpolator.
    // The following funcions initialize
	float2 dynamicLightmapUv = 0;
	#ifdef DYNAMICLIGHTMAP_ON
		dynamicLightmapUv = input.dynamicLightmapUv;
	#endif
    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, dynamicLightmapUv, unity_DynamicLightmapST, output.giSampling);
    OUTPUT_SH(output.normalWS, output.giSampling);

    return output;
}


#ifdef _DOUBLESIDED_ON
float4 ForwardLitFragment(Varyings input, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC) : SV_Target
#else
float4 ForwardLitFragment(Varyings input) : SV_Target
#endif
{
    UNITY_SETUP_INSTANCE_ID(input);

    FLIP_DOUBLESIDED(input, cullFace);

    SurfaceData surfaceData;
    float4 distortion = InitializeStandardLitSurfaceData(input.uv, input.positionCS, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    #if defined(SUPPORT_FOG_OF_WAR) && defined(_TRANSPARENT_ON)
		float fowFactor = GetFogOfWarFactor(inputData.positionWS);
		//return lerp(_FogOfWarColor.rgb, float3(1,1,1), fowFactor).rgbb;
		#if !defined(_TRANSPARENT_ON)
			// ранний выход можно сделать, только если рисуем Opaque-геометрию
			if (fowFactor <= 0)
			{
				return float4(_FogOfWarColor.rgb, surfaceData.alpha);
			}
		#endif
	#endif

    //float4 distortion = GetDistortion(inputData.positionSS.xy, surfaceData.normalTS, surfaceData.translucency.r, input.positionCS.w);
    //ModifySurfaceDataForDistortionBeforeLighting(surfaceData, distortion, input.positionCS.w, expDepthDiff);

	//ModifyAlbedoForDistortionBeforeLighting(surfaceData.albedo, surfaceData.alpha);
    
    //float shoreFoamMask = 1 - expDepthDiff;
    //shoreFoamMask = pow(shoreFoamMask, _FoamShorePower) * _FoamShoreScale;
    //return float4(shoreFoamMask.xxx, 1);

    float4 color = FragmentPBR(
        inputData,
        surfaceData.albedo,
        surfaceData.metallic,
        surfaceData.specular,
        surfaceData.smoothness,
        surfaceData.occlusion,
        surfaceData.emission,
        surfaceData.alpha,
		surfaceData.translucency * _Thickness * _TranslucencyColor.rgb,
        surfaceData.wrapDiffuseFactor,
		0 // materialFeatures
		);

	ApplyDistortion(distortion.rgb, color.rgb, surfaceData.alpha);

    FinalColorOutput(color);

	// туман нужно миксовать после перевода в Gamma-space, потому что пост-процессный туман работает через аддитивный блендинг в гамме (т.е. его невозможно перевести в линеар)
	// поэтому делаем все в гамме
    // TODO: в дисторшн текстуре уже наложен туман, поэтому степень наложения тумана нужно как-то уменьшать в зависимости от дисторшна
	color.rgb = MixFog(color.rgb, inputData.fogCoord);

	// FOW нужно делать ПОСЛЕ конверта в gamma-space, иначе будут артефакты в виде ступенчатого градиента
    #if defined(SUPPORT_FOG_OF_WAR) && defined(_TRANSPARENT_ON)
		ApplyFogOfWarFactor(fowFactor, color.rgb);
	#endif

	#ifdef DEBUG_DISPLAY
        //color.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, color.rgb);

		float4 vertexColor = 0;

		color.rgb = GetVertexAttributeDebug(vertexColor, color.rgb);
    #endif

	return color;
}

#endif // OWLCAT_WATER_FORWARD_PASS_INCLUDED
