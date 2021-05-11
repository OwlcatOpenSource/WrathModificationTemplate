#ifndef OWLCAT_LIT_FORWARD_PASS_INCLUDED
#define OWLCAT_LIT_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "ParticlesInput.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/DistortionUtils.hlsl"
#ifdef VAT_ENABLED
	#include "../../ShaderLibrary/VAT.hlsl"
#endif

struct Attributes
{
    float4 positionOS           : POSITION;
	float4 color				: COLOR0;
	float3 normalOS             : NORMAL;
	#if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
		float4 tangentOS            : TANGENT;
	#endif
    float4 texcoord             : TEXCOORD0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON) || defined(COLOR_ALPHA_RAMP) || defined(VAT_ENABLED)
		float4 customData1		: TEXCOORD1;
	#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS           : SV_POSITION;
	float4 color				: COLOR0;
    float4 uv                   : TEXCOORD0;
	float4 giSampling           : TEXCOORD1;
    float3 positionWS           : TEXCOORD2;
    float3 positionVS           : TEXCOORD3;
	float4 viewDir				: TEXCOORD4;
    float3 normalWS				: TEXCOORD5;
    #if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
        float3 tangentWS		: TEXCOORD6;
        float3 bitangentWS		: TEXCOORD7;
    #endif
	#if defined(TEXTURE1_ON) || defined(_NORMALMAP)
		float4 uv1				: TEXCOORD8;
	#endif
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		float4 noiseUv			: TEXCOORD9;
	#endif
	#if defined(FLUID_FOG) || defined(COLOR_ALPHA_RAMP) || defined(OPACITY_FALLOFF)
		float4 fluidAndRampUvAndOpacityFalloff	: TEXCOORD10;
	#endif
	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		float2 emissionUv		: TEXCOORD11;
	#endif
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

void InitializeInputData(Varyings input, float3 normalTS, out InputData inputData)
{
    inputData.positionWS = input.positionWS.xyz;
    inputData.positionSS = input.positionCS.xy;
    inputData.linearDepth = input.positionCS.w;

    #if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
        inputData.normalWS = TransformTangentToWorld(normalTS, float3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS;
    #endif

	inputData.normalWS = normalize(inputData.normalWS);

    inputData.viewDirectionWS = normalize(input.viewDir.xyz);

    inputData.fogCoord = ComputeFogFactor(input.positionCS.w);
    SampleGI(input.giSampling, inputData.positionWS, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);

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

	#ifdef VAT_ENABLED
		VAT(input.customData1.xy, input.color.rgb, input.positionOS.xyz, input.normalOS.xyz);
	#endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

	output.color = GetVertexOutputColor(input.color);

	float particleID = 0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		particleID = input.customData1.x;
	#endif

	#ifdef WORLD_UV_XZ
		input.texcoord.xy = vertexInput.positionWS.xz;
	#endif

	VaryingsUv uvInput = GetVaryingsUv(input.texcoord, particleID);

	output.uv.xy = uvInput.tex0Uv;
	output.uv.zw = uvInput.originalUv;

	#if defined(TEXTURE1_ON)
		output.uv1.xy = uvInput.tex1Uv;
	#endif

	#if defined(_NORMALMAP)
		output.uv1.zw = uvInput.bumpUv;
	#endif

	#if defined(NOISE0_ON)
		output.noiseUv.xy = uvInput.noiseUv0;
	#endif

	#if defined(NOISE1_ON)
		output.noiseUv.zw = uvInput.noiseUv1;
	#endif

	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		output.emissionUv = uvInput.emissionUv;
	#endif

    output.positionWS = vertexInput.positionWS;
    output.positionVS = vertexInput.positionVS;
    output.positionCS = vertexInput.positionCS;
    output.viewDir.xyz = normalize(_WorldSpaceCameraPos - output.positionWS);

	if (_VirtualOffsetVertexPosition)
	{
		output.positionWS += output.viewDir.xyz * _VirtualOffset;
	}

	#if defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON)
		VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

		#if defined(OVERRIDE_NORMAL_ON) && defined(PARTICLES_LIGHTING_ON)
			normalInput.normalWS = output.viewDir.xyz;
		#endif

		#ifdef _NORMALMAP
			output.normalWS = normalInput.normalWS;
			output.tangentWS = normalInput.tangentWS;
			output.bitangentWS = normalInput.bitangentWS;
		#else
			output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
		#endif
	#else
		VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
		output.normalWS = normalInput.normalWS;
	#endif

    // We either sample GI from lightmap or SH. lightmap UV and vertex SH coefficients
    // are packed in lightmapUVOrVertexSH to save interpolator.
    // The following functions initialize
    //OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.giSampling);
    OUTPUT_SH(output.normalWS, output.giSampling);

	#if defined(FLUID_FOG)
		output.fluidAndRampUvAndOpacityFalloff.xy = TRANSFORM_TEX(output.positionWS.xz, _FluidFogMask);
	#endif

	#if defined(COLOR_ALPHA_RAMP)
		output.fluidAndRampUvAndOpacityFalloff.z = input.customData1.y * _RandomizeRampOffset;
	#endif

	#if defined(OPACITY_FALLOFF)
		float VdotN = dot(output.viewDir.xyz, output.normalWS);
		float vertexNormalsSlope = max(0.0, abs(VdotN));
		#if defined(INVERT_OPACITY_FALLOFF)
			float2 madCoeff = float2(1, -1);
		#else
			float2 madCoeff = float2(0, 1);
		#endif
			vertexNormalsSlope = saturate(madCoeff.x + madCoeff.y * vertexNormalsSlope);
			output.fluidAndRampUvAndOpacityFalloff.w = pow(vertexNormalsSlope, _OpacityFalloff);
	#endif

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

	float4 uv1 = 0;
	#if defined(TEXTURE1_ON) || defined(_NORMALMAP)
		uv1 = input.uv1;
	#endif

	float alphaRampOffset = 0;
	#if defined(COLOR_ALPHA_RAMP)
		alphaRampOffset = input.fluidAndRampUvAndOpacityFalloff.z;
	#endif
	float4 noiseUv = 0;
	#if defined(NOISE0_ON) || defined(NOISE1_ON)
		noiseUv = input.noiseUv;
	#endif
	float softFactor = 1;
	#if defined(SOFT_PARTICLES) && defined(_TRANSPARENT_ON)
		float sceneZ = LinearEyeDepth(LOAD_TEXTURE2D(_CameraDepthRT, input.positionCS.xy).x) +_VirtualOffset;
		softFactor = saturate(1.0 - exp(-_Softness * (sceneZ - input.positionCS.w)));
	#endif
	float opacityFalloffFactor = 1;
	#if defined(OPACITY_FALLOFF)
		opacityFalloffFactor = input.fluidAndRampUvAndOpacityFalloff.w;
	#endif
	float2 fluidFogUv = 0;
	#if defined(FLUID_FOG)
		fluidFogUv = input.fluidAndRampUvAndOpacityFalloff.xy;
	#endif
	float2 emissionUv = 0;
	#if defined(_EMISSION) && defined(_EMISSIONMAP)
		emissionUv = input.emissionUv;
	#endif
	SurfaceUv surfaceUv = GetSurfaceUv(input.uv, uv1, alphaRampOffset, noiseUv, fluidFogUv, emissionUv);
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(surfaceUv, input.color, softFactor, opacityFalloffFactor, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    #if defined(SUPPORT_FOG_OF_WAR) && defined(_TRANSPARENT_ON)
		float fowFactor = 1;
		if (_FogOfWarMaterialFlag > 0)
		{
			fowFactor = GetFogOfWarFactor(inputData.positionWS);
		}

		#if !defined(_TRANSPARENT_ON)
			// ранний выход можно сделать, только если рисуем Opaque-геометрию
			if (fowFactor <= 0)
			{
				return float4(_FogOfWarColor.rgb, surfaceData.alpha);
			}
		#endif
	#endif

	#ifdef PASS_DISTORTION_VECTORS
		float4 distortionOutput;
		EncodeDistortion(
			-surfaceData.normalTS.xy * _Distortion + _DistortionOffset.xy,
			1 - surfaceData.translucency.r * _DistortionThicknessScale,
			surfaceData.alpha * softFactor,
			distortionOutput);
		return distortionOutput;
	#endif

	#if defined(PARTICLES_LIGHTING_ON)
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
			0
			);
		ApplyDistortion(inputData.positionSS.xy, surfaceData.normalTS, surfaceData.translucency.r, input.positionCS.w, color.rgb, surfaceData.alpha);
	#else
		float4 color = float4(surfaceData.albedo.rgb, surfaceData.alpha);
		color.rgb += surfaceData.emission;

		#if defined(DISTORTION_ON)
			#if defined(_TRANSPARENT_ON)
				if (_DistortionDoesNotUseAlpha > 0)
				{
				
				}
				else
				{
					color.a *= (1 - _DistortionColorFactor);
				}
			#else
				float3 distortion = GetDistortion(inputData.positionSS.xy, surfaceData.normalTS, surfaceData.translucency, input.positionCS.z).xyz;
				if (_DistortionDoesNotUseAlpha > 0)
				{
					color.rgb = lerp(distortion.rgb, color.rgb, color.a);
				}
				else
				{
					color.rgb = lerp(color.rgb, distortion, _DistortionColorFactor);
				}
			#endif
		#endif
	#endif

	FinalColorOutput(color);

	// туман накладываем только на прозрачку, на opaque-геометрию туман наложится в пост-процессе
	#ifdef _TRANSPARENT_ON
		float3 preFogColor = color.rgb;
		color.rgb = MixFog(color.rgb, inputData.fogCoord);
		color.rgb = lerp(preFogColor.rgb, color.rgb, _FogInfluence);
	#endif

    #if defined(SUPPORT_FOG_OF_WAR) && defined(_TRANSPARENT_ON)
		ApplyFogOfWarFactor(fowFactor, color.rgb);
	#endif

	#if defined(SOFT_PARTICLES)
		// Костыль из PF1
		color.a *= (softFactor);
	#endif

	// очень важно делать preMultiply после перевода в Gamma Space, чтобы получить результат как PF1
	#if defined(_ALPHAPREMULTIPLY_ON)
		color.rgb *= color.a;
	#endif

	color.rgb = clamp(color.rgb, float3(0, 0, 0), _HdrColorClamp.xxx);

	#if defined(_ALPHABLENDMULTIPLY_ON)
		color = lerp(float4(1, 1, 1, 1), color, color.a);
	#endif

	#ifdef DEBUG_DISPLAY

		if(_DebugMipMap > 0)
		{
			color.rgb = GetMipMapDebug(input.uv.xy, _BaseMap_TexelSize.zw, color.rgb);
		}

		float4 vertexColor = 0;
		vertexColor = input.color;

		if (_DebugVertexAttribute != 0)
		{
			color.rgb = GetVertexAttributeDebug(vertexColor, color.rgb);
		}
    #endif

	return color;
}

#endif // OWLCAT_LIT_FORWARD_PASS_INCLUDED
