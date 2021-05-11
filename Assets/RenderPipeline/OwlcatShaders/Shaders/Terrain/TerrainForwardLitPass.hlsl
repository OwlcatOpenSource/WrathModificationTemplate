#ifndef OWLCAT_TERRAIN_FORWARD_LIT_PASS_INCLUDED
#define OWLCAT_TERRAIN_FORWARD_LIT_PASS_INCLUDED

#include "TerrainInput.hlsl"
#include "TerrainCommon.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 vertex				: POSITION;
    float3 normal				: NORMAL;
    float2 texcoord				: TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 uvMainAndLM					: TEXCOORD0; // xy: control, zw: lightmap
    float4 viewDir						: TEXCOORD1;
    float3 positionWS					: TEXCOORD2;
    float3 positionVS					: TEXCOORD3;
    float3 normalWS						: TEXCOORD4;
    #if !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
        float3 tangentWS				: TEXCOORD5;
        float3 bitangentWS				: TEXCOORD6;
    #endif
    #ifdef _TRIPLANAR
        float3 positionOS				: TEXCOORD7;
    #endif
	#ifdef DYNAMICLIGHTMAP_ON
		float2 dynamicLightmapUv		: TEXCOORD8;
	#endif
	float4 positionCS : SV_POSITION;
};

void InitializeInputData(Varyings input, float3 normalWS, out InputData inputData)
{
    inputData.positionWS = input.positionWS.xyz;
    inputData.positionSS = input.positionCS.xy;
    inputData.linearDepth = input.positionCS.w;

    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = normalize(input.viewDir.xyz);

    inputData.fogCoord = ComputeFogFactor(input.positionCS.w);
	// Запеченное освещение читаем из GBuffer'а
	float4 gBufferData1 = LOAD_TEXTURE2D(_CameraBakedGIRT, inputData.positionSS.xy);
	inputData.bakedGI = gBufferData1.rgb;
	// Shadowmask семплим как обычно, она не поместилась в GBuffer
	inputData.shadowMask = SampleShadowmask(input.uvMainAndLM.zwzw);
    /*#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
		float2 dynamicLightmapUv = 0;
		#ifdef DYNAMICLIGHTMAP_ON
			dynamicLightmapUv = input.dynamicLightmapUv;
		#endif
        inputData.bakedGI = SampleLightmap(input.uvMainAndLM.zw, dynamicLightmapUv, input.normalWS);
        #ifdef SHADOWS_SHADOWMASK
            inputData.shadowMask = SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_Lightmap, input.uvMainAndLM.zw); // Reuse sampler from Lightmap
        #else
            inputData.shadowMask = 0;
        #endif
    #else
        inputData.bakedGI = 0;
        inputData.shadowMask = 0;
    #endif*/

    float depth = LinearViewDepth(input.positionVS, input.positionCS);

	inputData.depthSliceIndex = depth * _Clusters.z;
    inputData.clusterUv = uint3(inputData.positionSS * _ScreenSize.zw * _Clusters.xy, inputData.depthSliceIndex);
}

Varyings Vert(Attributes input)
{
    Varyings OUT = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    TerrainInstancing(input.vertex, input.normal, input.texcoord);

    OUT.uvMainAndLM.xy = input.texcoord;
    OUT.uvMainAndLM.zw = input.texcoord * unity_LightmapST.xy + unity_LightmapST.zw;
	#ifdef DYNAMICLIGHTMAP_ON
		OUT.dynamicLightmapUv = input.texcoord * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
	#endif

    OUT.positionWS = TransformObjectToWorld(input.vertex.xyz);
    OUT.positionVS = TransformWorldToView(OUT.positionWS);
    OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
    #ifdef _TRIPLANAR
        OUT.positionOS = input.vertex.xyz;
    #endif
    OUT.viewDir.xyz = _WorldSpaceCameraPos - OUT.positionWS;

    #if !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
        float4 tangentOS = float4(cross(float3(0, 0, 1), input.normal), 1.0);
        // mikkts space compliant. only normalize when extracting normal at frag.
        float sign = tangentOS.w * GetOddNegativeScale();
        OUT.normalWS = TransformObjectToWorldNormal(input.normal);
        OUT.tangentWS = TransformObjectToWorldDir(tangentOS.xyz);
        OUT.bitangentWS = cross(OUT.normalWS, OUT.tangentWS) * sign;
    #else
        OUT.normalWS = TransformObjectToWorldNormal(input.normal);
    #endif

    return OUT;
}

float4 Frag(Varyings input) : SV_Target
{
    float3 normalWS = DecodeNormal(LOAD_TEXTURE2D(_CameraNormalsRT, input.positionCS.xy).rgb);

    #ifdef TERRAIN_SPLAT_BASEPASS
		float4 mainTexSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvMainAndLM.xy);
        float3 albedo = mainTexSample.rgb;
        float smoothness = mainTexSample.a;
        float metallic = SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, input.uvMainAndLM.xy).r;
        float3 emission = 0;
    #else
        #ifdef _TRIPLANAR
            float3 vertexNormal = input.normalWS;

            #ifdef ENABLE_TERRAIN_PERPIXEL_NORMAL
                float2 sampleCoords = (input.uvMainAndLM.xy / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
                vertexNormal = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
            #endif
        #else
            float3 vertexNormal = 0;
        #endif

        float4 mixedDiffuse;
        float4 mixedMasks;
		float3 positionOS = 0;
		#ifdef _TRIPLANAR
			positionOS = input.positionOS;
		#endif
        SplatmapMix(input.uvMainAndLM.xy, positionOS, vertexNormal, mixedDiffuse, mixedMasks);

        float3 albedo = mixedDiffuse.rgb;
        float smoothness = 1.0 - mixedMasks.r;
        float3 emission = albedo.rgb * mixedMasks.g;
        float metallic = mixedMasks.b;
        //return mixedDiffuse;
    #endif

    InputData inputData;
    InitializeInputData(input, normalWS, inputData);

    #ifdef SUPPORT_FOG_OF_WAR
		float fowFactor = GetFogOfWarFactor(inputData.positionWS);
		if (fowFactor <= 0)
		{
			return float4(_FogOfWarColor.rgb, 0);
		}
	#endif

    float4 color = FragmentPBR(
        inputData,
        albedo,
        metallic,
        float3(0.0h, 0.0h, 0.0h), // specular
        smoothness,
        1.0, // occlusion,
        emission.rgb, // emission
        1.0, // alpha
		0.0, // translucency
        0.0, // wrapDiffuseFactor
		0 // materialFeatures
		);

    FinalColorOutput(color);

	// туман нужно миксовать после перевода в Gamma-space, потому что пост-процессный туман работает через аддитивный блендинг в гамме (т.е. его невозможно перевести в линеар)
	// поэтому делаем все в гамме
	color.rgb = MixFog(color.rgb, inputData.fogCoord);

	// FOW нужно делать ПОСЛЕ конверта в gamma-space, иначе будут артефакты в виде ступенчатого градиента
    #ifdef SUPPORT_FOG_OF_WAR
		ApplyFogOfWarFactor(fowFactor, color.rgb);
	#endif

	#ifdef DEBUG_DISPLAY
		float4 vertexColor = 0;

		color.rgb = GetVertexAttributeDebug(vertexColor, color.rgb);
    #endif

    return color;
}

#endif //OWLCAT_TERRAIN_FORWARD_LIT_PASS_INCLUDED
