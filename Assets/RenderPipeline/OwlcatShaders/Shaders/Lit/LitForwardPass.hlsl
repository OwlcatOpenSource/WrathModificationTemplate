#ifndef OWLCAT_LIT_FORWARD_PASS_INCLUDED
#define OWLCAT_LIT_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "LitInput.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/GPUSkinning.hlsl"
#include "../../ShaderLibrary/DistortionUtils.hlsl"
#ifdef VAT_ENABLED
	#include "../../ShaderLibrary/VAT.hlsl"
#endif
#ifdef VERTEX_ANIMATION_ENABLED
	#include "../../ShaderLibrary/VertexAnimation.hlsl"
#endif

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
    #if defined(_GPU_SKINNING) || defined(PBD_SKINNING)
        float4 blendWeights     : BLENDWEIGHTS0;
        uint4 blendIndices      : BLENDINDICES0;
    #endif
	#if defined(PBD_MESH)
		uint vertexId			: VERTEXID_SEMANTIC;
	#endif
	#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED)
		float4 color			: COLOR0;
	#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS           : SV_POSITION;
    float4 uv                   : TEXCOORD0;
	float2 uv2					: TEXCOORD1;
    float4 giSampling           : TEXCOORD2;
    float3 positionWS           : TEXCOORD3;
    float3 positionVS           : TEXCOORD4;
    float3 normalWS				: TEXCOORD5;
    #if defined(_NORMALMAP)
        float3 tangentWS		: TEXCOORD6;
        float3 bitangentWS		: TEXCOORD7;
    #endif
    float4 viewDir				: TEXCOORD8;
	#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || (defined(DEBUG_DISPLAY) && defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED))
		float4 color			: TEXCOORD9;
	#endif
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

	#ifdef PBD_SKINNING
		PbdSkin(input.blendWeights, input.blendIndices, input.positionOS.xyz, input.normalOS.xyz, input.tangentOS.xyzw);
	#endif

	#ifdef PBD_MESH
		PbdMesh(input.vertexId, input.positionOS.xyz, input.normalOS.xyz, input.tangentOS.xyzw);
	#endif

	#ifdef PBD_GRASS
		PbdGrass(input.positionOS.xyz);
	#endif

	#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || (defined(DEBUG_DISPLAY) && defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED))
		output.color = input.color;
	#endif

	#ifdef VAT_ENABLED
		VAT(input.lightmapUV.xy, input.color.rgb, input.positionOS.xyz, input.normalOS.xyz);
	#endif

	#ifdef VERTEX_ANIMATION_ENABLED
		VertexAnimation(input.color, input.positionOS.xyz);
	#endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
	#if DISSOLVE_ON
		output.uv.zw = TRANSFORM_TEX(input.texcoord, _DissolveMap);
	#endif
	#if ADDITIONAL_ALBEDO
		output.uv2.xy = TRANSFORM_TEX(input.texcoord, _AdditionalAlbedoMap);
	#endif

    output.positionWS = vertexInput.positionWS;
    output.positionVS = vertexInput.positionVS;
    output.positionCS = vertexInput.positionCS;
    output.viewDir.xyz = _WorldSpaceCameraPos - output.positionWS;

    #ifdef _NORMALMAP
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
    InitializeStandardLitSurfaceData(input.uv.xy, input.positionCS.xy, surfaceData);

	#if defined(INDIRECT_INSTANCING)
		//return ((_ArgsOffset - 4.0f) / 5.0f) / 200;
        //uint meshID = _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID].meshID;
        //uint startInstance = _ArgsBuffer[_ArgsOffset];
        //if (unity_InstanceID < 132)
        //{
        //    return 1;
        //}
        //else
        //{
        //    return 0;
        //}
		#ifdef USE_GROUND_COLOR
			surfaceData.albedo = lerp(surfaceData.albedo, _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID].tintColor, _GroundColorPower * (1 - input.color.r));
		#endif
		//surfaceData.albedo = _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID].tintColor.rgb;
	#endif

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

	#ifdef PASS_FORWARD_LIT
		AdditionalAlbedoMix(input.uv2.xy, surfaceData);

		if(_RimLighting)
		{
			RimLighting(inputData.normalWS, inputData.viewDirectionWS, surfaceData);
		}
	#endif

	Dissolve(input.uv.zw, surfaceData);

	// _DistortionOffset - используется только в Particles.shader, поэтому здесь его зануляем
    _DistortionOffset = 0;

	#ifdef PASS_DISTORTION_VECTORS
		float4 distortionOutput;
		EncodeDistortion(
			-surfaceData.normalTS.xy * _Distortion + _DistortionOffset.xy,
			1 - surfaceData.translucency.r * _DistortionThicknessScale,
			surfaceData.alpha,
			distortionOutput);
		return distortionOutput;
	#endif

	#ifdef PASS_FORWARD_LIT
		ModifyAlbedoForDistortionBeforeLighting(surfaceData.albedo, surfaceData.alpha);

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

		ApplyDistortion(inputData.positionSS.xy, surfaceData.normalTS, surfaceData.translucency.r, input.positionCS.w, color.rgb, surfaceData.alpha);

		FinalColorOutput(color);

		// туман нужно миксовать после перевода в Gamma-space, потому что пост-процессный туман работает через аддитивный блендинг в гамме (т.е. его невозможно перевести в линеар)
		// поэтому делаем все в гамме
		// туман накладываем только на прозрачку, на opaque-геометрию туман наложится в пост-процессе
		#ifdef _TRANSPARENT_ON
			color.rgb = MixFog(color.rgb, inputData.fogCoord);
		#endif

		// FOW нужно делать ПОСЛЕ конверта в gamma-space, иначе будут артефакты в виде ступенчатого градиента
		#if defined(SUPPORT_FOG_OF_WAR) && defined(_TRANSPARENT_ON)
			ApplyFogOfWarFactor(fowFactor, color.rgb);
		#endif

		#ifdef DEBUG_DISPLAY
			color.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, color.rgb);

			float4 vertexColor = 0;
			#if (defined(USE_GROUND_COLOR) && defined(INDIRECT_INSTANCING)) || defined(VAT_ENABLED) || defined(VERTEX_ANIMATION_ENABLED)
				vertexColor = input.color;
			#endif

			color.rgb = GetVertexAttributeDebug(vertexColor, color.rgb);
		#endif

		// очень важно делать preMultiply после перевода в Gamma Space, чтобы получить результат как PF1
		#if defined(_ALPHAPREMULTIPLY_ON) && defined(_TRANSPARENT_ON)
			color.rgb *= color.a;
		#endif

		return color;
	#endif
}

#endif // OWLCAT_LIT_FORWARD_PASS_INCLUDED
