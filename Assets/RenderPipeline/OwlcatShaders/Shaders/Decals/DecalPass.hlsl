#ifndef OWLCAT_DECAL_PASS_INCLUDED
#define OWLCAT_DECAL_PASS_INCLUDED

#include "DecalInput.hlsl"
#include "../../Lighting/DeferredData.cs.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/GBufferUtils.hlsl"

#define UNITY_PI            3.14159265359f

#ifdef FULL_SCREEN_DECALS
    struct Attributes
    {
        uint vertexID : VERTEXID_SEMANTIC;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
#else
    struct Attributes
    {
        float4 vertex : POSITION;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
#endif

struct Varyings
{
    float4 positionCS				: SV_POSITION;
	float3 normalWS					: TEXCOORD0;
	#if defined(_NORMALMAP)
        float3 tangentWS			: TEXCOORD1;
        float3 bitangentWS			: TEXCOORD2;
    #endif
    float3 cameraRay				: TEXCOORD3;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#if UNITY_REVERSED_Z
    #define MIN_DEPTH(l, r) max(l, r)
#else
    #define MIN_DEPTH(l, r) min(l, r)
#endif

struct CircleUv
{
	float radius;
	float angle;
	float distFromCenter;
	int segmentCount;
};

struct DecalInput
{
	float3 positionWS;
	float3 normalWS;
	#if defined(DEFERRED_ON)
		float smoothness;
	#endif
	#if defined(_SLOPE_FADE)
		float3 hardEdgeNormalWS;
	#endif
	float deviceDepth;
	float3 positionDS;
	float2 uv;
	float4 textureGradients;
	CircleUv circleUv;
	#if defined(RADIAL_ALPHA)
		float radialAlphaGrad;
	#endif
};

inline float3 MinDiff(float3 P, float3 Pr, float3 Pl, float3 defaultV)
{
	float3 V1 = Pr - P;
	float3 V2 = P - Pl;
	float cosA = dot(normalize(V1), normalize(V2));
	if (cosA <= 0)
	{
		return defaultV;
	}
	return (dot(V1, V1) < dot(V2, V2)) ? V1 : V2;
}

float2 TransformUv(DecalInput decalInput, float4 textureST, float2 scrollSpeed)
{
	switch (_UvMapping)
	{
		case DECAL_UV_MAPPING_LOCAL:
		case DECAL_UV_MAPPING_WORLD:
		{
			return (decalInput.uv * textureST.xy + textureST.zw) + scrollSpeed.xy * _Time.yy;
		}

		default:
		case DECAL_UV_MAPPING_RADIAL:
		{
			float x = decalInput.circleUv.angle * (int)textureST.x + textureST.z + scrollSpeed.x * _Time.y;
			float y = decalInput.circleUv.distFromCenter * textureST.y + textureST.w + scrollSpeed.y * _Time.y;
			return float2(x, y);
		}
	}
}

// написано по статье http://www.humus.name/index.php?page=3D&ID=84
// модифицировано по статье https://www.slideshare.net/philiphammer/dissecting-the-rendering-of-the-surge
// во второй ссылке неправильный паттерн семлирования (см. http://wojtsterna.blogspot.com/2018/02/directx-11-hlsl-gatherred.html)
// Sample 2 quads
//		+------+------+
//		|      |      |
//		| d0.w | d0.z |
//		+------+------+------+
//		|      | d0.y |      |
//		| d0.x | d1.w | d1.z |
//		+------+------+------+
//		       |      |      |
//			   | d1.x | d1.y |
//			   +------+------+
DecalInput GetDecalInput(float2 positionCS)
{
	DecalInput result = (DecalInput)0;

	#ifdef DEFERRED_ON
		float4 gBufferNormalAndSmoothness = DecodeNormalAndSmoothness(LOAD_TEXTURE2D(_CameraNormalsRT, positionCS.xy));
		result.normalWS = gBufferNormalAndSmoothness.rgb;
		result.smoothness = gBufferNormalAndSmoothness.a;
	#else
		result.normalWS = DecodeNormalAndSmoothness(LOAD_TEXTURE2D(_CameraNormalsRT, positionCS.xy)).rgb;
	#endif

	float4 screenUv = (positionCS.xyxy + float4(-1, -1, 0, 0)) * _ScreenSize.zwzw;
	const float4 d0 = GatherDepthTexture(screenUv.xy);
	const float4 d1 = GatherDepthTexture(screenUv.zw);

	float d = d1.w;
	result.deviceDepth = d;
	float dx0 = d0.x;// Depth.Load(texCoord, int2(-1,  0));
	float dx1 = d1.z;// Depth.Load(texCoord, int2(+1,  0));
	float dy0 = d0.z;// Depth.Load(texCoord, int2( 0, -1));
	float dy1 = d1.x;// Depth.Load(texCoord, int2( 0, +1));

	// Find suitable neighbor screen positions in x and y so we can compute proper gradients
	// Select based on the smallest different in depth
    float4 screen_pos_x, screen_pos_y;
	float absDx0 = abs(dx0 - d);
	float absDx1 = abs(dx1 - d);
	float absDy0 = abs(dy0 - d);
	float absDy1 = abs(dy1 - d);
	float minDx, minDy;

    if (absDx0 < absDx1)
	{
        screen_pos_x = float4(positionCS.xy + float2(-1.0f, 0.0f), dx0, 1);
		minDx = absDx0;
	}
    else
	{
        screen_pos_x = float4(positionCS.xy + float2(1.0f, 0.0f), dx1, -1);
		minDx = absDx1;
	}

	if (abs(dx0 - dx1) < minDx)
	{
		screen_pos_x.z = d;
	}

    if (absDy0 < absDy1)
	{
        screen_pos_y = float4(positionCS.xy + float2(0.0f, -1.0f), dy0, 1);
		minDy = absDy0;
	}
    else
	{
        screen_pos_y = float4(positionCS.xy + float2(0.0f, 1.0f), dy1, -1);
		minDy = absDy1;
	}

	if (abs(dy0 - dy1) < minDy)
	{
		screen_pos_y.z = d;
	}

	result.positionWS = ComputeWorldSpacePosition(positionCS.xy * _ScreenSize.zw, d, UNITY_MATRIX_I_VP);
	float3 positionDX = ComputeWorldSpacePosition(screen_pos_x.xy * _ScreenSize.zw, screen_pos_x.z, UNITY_MATRIX_I_VP);
    float3 positionDY = ComputeWorldSpacePosition(screen_pos_y.xy * _ScreenSize.zw, screen_pos_y.z, UNITY_MATRIX_I_VP);

	#if defined(_SLOPE_FADE)
		result.hardEdgeNormalWS = -normalize(cross((result.positionWS - positionDX) * screen_pos_x.w, (result.positionWS - positionDY) * screen_pos_y.w));
	#endif

	// Transform from relative world space to decal space (DS) to clip the decal
    result.positionDS = TransformWorldToObject(result.positionWS);
	result.positionDS = result.positionDS * float3(1.0, -1.0, 1.0) + float3(0.5, 0.5, 0.5);

	switch (_UvMapping)
	{
		case DECAL_UV_MAPPING_LOCAL:
		{
			result.uv = result.positionDS.xz;
			positionDX = TransformWorldToObject(positionDX);
			positionDX = positionDX * float3(1.0, -1.0, 1.0) + float3(0.5, 0.5, 0.5);
			positionDY = TransformWorldToObject(positionDY);
			positionDY = positionDY * float3(1.0, -1.0, 1.0) + float3(0.5, 0.5, 0.5);
		}
		break;

		case DECAL_UV_MAPPING_WORLD:
		{
			result.uv = result.positionWS.xz;		
		}
		break;

		case DECAL_UV_MAPPING_RADIAL:
		{
			result.uv = result.positionDS.xz;
			positionDX = TransformWorldToObject(positionDX);
			positionDX = positionDX * float3(1.0, -1.0, 1.0) + float3(0.5, 0.5, 0.5);
			positionDY = TransformWorldToObject(positionDY);
			positionDY = positionDY * float3(1.0, -1.0, 1.0) + float3(0.5, 0.5, 0.5);

			result.circleUv.radius = GetObjectToWorldMatrix()._m00;
			float2 radialUv = result.uv * 2 - 1;
			result.circleUv.angle = atan2(radialUv.y, radialUv.x);
			result.circleUv.angle = (result.circleUv.angle / (UNITY_PI * 2)) + .5;
			result.circleUv.distFromCenter = length(radialUv);
			/*float uvX = angle * (int)_BaseMap_ST.x + _BaseMap_ST.z;
			uvX *= (int)segmentCount;

			float uvY = saturate((result.circleUv.distFromCenter * radius - radius + _BaseMap_ST.y) / _BaseMap_ST.y);
			result.circleUv = float2(uvX, uvY);*/
		}
		break;
	}

	result.textureGradients = float4(result.uv.xy - positionDX.xz, result.uv.xy - positionDY.xz);

	#ifdef PROJECTOR
        clip(result.positionDS); // clip negative value
        clip(1.0 - result.positionDS); // Clip value above one
    #endif

	return result;
}

float4 SampleDecalTextureGrad(TEXTURE2D_PARAM(textureName, samplerName), float2 uv, float4 gradients)
{
	float4 result = SAMPLE_TEXTURE2D_GRAD(textureName, samplerName, uv, gradients.xy, gradients.zw);
	#if !defined(UNITY_COLORSPACE_GAMMA)
		result.rgb = LinearToSRGB(result.rgb);
	#endif

	return result;
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////
Varyings DecalVertex(Attributes input)
{
    Varyings output = (Varyings) 0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

	output.normalWS = TransformObjectToWorldNormal(float3(0, 1, 0));
	#if(_NORMALMAP)
		output.tangentWS = TransformObjectToWorldNormal(float3(1, 0, 0));
		output.bitangentWS = TransformObjectToWorldNormal(float3(0, 0, 1));
	#endif

    #ifdef FULL_SCREEN_DECALS
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.cameraRay = CreateRay(output.positionCS.xy);
    #else
        output.positionCS = TransformObjectToHClip(input.vertex.xyz);
        // деление не интерполируется, поэтому переносим его в пиксельный шейдер
        //OUT.cameraRay = CreateRay(output.positionCS.xy / output.positionCS.w);
        output.cameraRay = output.positionCS.xyw;
    #endif

    return output;
}

// Force the stencil test before the UAV write.
[earlydepthstencil]
#ifdef DEFERRED_ON
void DecalFragment(Varyings input, out float4 colorOutput : SV_Target0, out float4 normal : SV_Target1, out float4 smoothnessAndMetallic : SV_Target2)
#else
float4 DecalFragment(Varyings input) : SV_Target0
#endif
{
    UNITY_SETUP_INSTANCE_ID(input);

	DecalInput decalInput = GetDecalInput(input.positionCS.xy);

    #ifdef SUPPORT_FOG_OF_WAR
		float fowFactor = GetFogOfWarFactor(decalInput.positionWS);
		if (fowFactor <= 0)
		{
			return float4(_FogOfWarColor.rgb, 0);
		}
	#endif
    
	//float deviceDepth = SampleDepthAndCheckDicountinuity(IN.positionCS.xy, useFirstMip);
    //float deviceDepth = LOAD_TEXTURE2D(_CameraDepthRT, IN.positionCS.xy).x;
    //float3 positionWS = ComputeWorldSpacePosition(IN.positionCS.xy * _ScreenSize.zw, deviceDepth, UNITY_MATRIX_I_VP);

    //#ifndef FULL_SCREEN_DECALS
    //    IN.cameraRay = CreateRay(IN.cameraRay.xy / IN.cameraRay.z);
    //#endif
    //float3 positionWS = ReconstructPositionFromDeviceDepth(IN.cameraRay, _WorldSpaceCameraPos, deviceDepth);

	float2 noiseUv0 = 0;
	float2 noiseUv1 = 0;

	#if (defined(NOISE_UV_CORRECTION) && (defined(NOISE0_ON) || defined(NOISE1_ON)))
		float2 uvCorrection = decalInput.uv * 2.0 - 1.0;
		float noiseFade = saturate(1 - length(uvCorrection));
	#endif

	#if defined(NOISE0_ON)
		noiseUv0 = TransformUv(decalInput, _Noise0Tex_ST, _Noise0Speed.xy);// TRANSFORM_TEX_SCROLL(decalInput.uv, _Noise0Tex, _Noise0Speed.xy);
		noiseUv0 = SampleDecalTextureGrad(TEXTURE2D_ARGS(_Noise0Tex, sampler_Noise0Tex), noiseUv0, decalInput.textureGradients.xyzw * _Noise0Tex_ST.xyxy).rg * 2.0 - 1.0;
		#if defined(NOISE_UV_CORRECTION)
			_Noise0Scale *= noiseFade;
		#endif
		noiseUv0 *= _Noise0Scale;
	#endif

	#if defined(NOISE1_ON)
		noiseUv1 = TransformUv(decalInput, _Noise1Tex_ST, _Noise1Speed.xy);// TRANSFORM_TEX_SCROLL(decalInput.uv, _Noise1Tex, _Noise1Speed.xy);
		noiseUv1 = SampleDecalTextureGrad(TEXTURE2D_ARGS(_Noise1Tex, sampler_Noise1Tex), noiseUv1, decalInput.textureGradients.xyzw * _Noise1Tex_ST.xyxy).rg * 2.0 - 1.0;
		#if defined(NOISE_UV_CORRECTION)
			_Noise1Scale *= noiseFade;
		#endif
		noiseUv1 *= _Noise1Scale;
	#endif

	float2 uvNoised = noiseUv0 + noiseUv1;

	float2 uv0 = TransformUv(decalInput, _BaseMap_ST, _UV0Speed.xy) + uvNoised;
	float4 albedoAlpha = SAMPLE_TEXTURE2D_GRAD(_BaseMap, sampler_BaseMap, uv0, decalInput.textureGradients.xy * _BaseMap_ST.xy, decalInput.textureGradients.zw * _BaseMap_ST.xy);

	#if defined(TEXTURE1_ON)
		float2 uv1 = TransformUv(decalInput, _MainTex1_ST, _UV1Speed.xy) + uvNoised;// TRANSFORM_TEX_SCROLL(decalInput.uv, _MainTex1, _UV1Speed.xy);
		float4 tex1 = SAMPLE_TEXTURE2D_GRAD(_MainTex1, sampler_MainTex1, uv1, decalInput.textureGradients.xy * _MainTex1_ST.xy, decalInput.textureGradients.zw * _MainTex1_ST.xy);

		if (_Tex1MixMode <= 1)
		{
			albedoAlpha = lerp(albedoAlpha, tex1, _MainTex1Weight);
		}
		else
		{
			albedoAlpha.rgb = lerp(albedoAlpha.rgb, tex1.rgb, _MainTex1Weight);
			albedoAlpha.a *= tex1.a;
		}
	#endif

	#if defined(COLOR_ALPHA_RAMP)
		float2 rampUv = float2(albedoAlpha.a * _ColorAlphaRamp_ST.x + _ColorAlphaRamp_ST.z, .5);
		rampUv.x += _RampScrollSpeed * _Time.y;
		float3 ramp = SAMPLE_TEXTURE2D_LOD(_ColorAlphaRamp, sampler_ColorAlphaRamp, rampUv, 0).rgb;
		albedoAlpha.rgb = lerp(ramp, ramp * albedoAlpha.rgb, _RampAlbedoWeight);
	#endif

	albedoAlpha.rgb *= _BaseColor.rgb * _HdrColorScale.rrr;

	float alphaModifier = 1;
	#if defined(_SLOPE_FADE)
        float3 forwardWS = normalize(GetObjectToWorldMatrix()._12_22_32);
        float slopeFactor = dot(lerp(decalInput.normalWS, decalInput.hardEdgeNormalWS, _DecalSlopeHardEdgeNormalFactor), forwardWS) + (1 - _DecalSlopeFadeStart);
        slopeFactor = max(0, slopeFactor);
		slopeFactor = pow(slopeFactor, _DecalSlopeFadePower);
        alphaModifier *= saturate(slopeFactor);
    #endif

    #if defined(_GRADIENT_FADE) && !defined(FULL_SCREEN_DECALS)
        decalInput.positionDS.y = decalInput.positionDS.y * 2.0 - 1.0;
        float gradientFactor = abs(decalInput.positionDS.y);
		
		if (_DecalExpGradient > 0)
		{
			gradientFactor = 1 - saturate(pow(gradientFactor, 3));
		}
		else
		{
			gradientFactor = 1 - gradientFactor;
		}

        gradientFactor += _DecalGradientMode == 0 && decalInput.positionDS.y > 0 ? 1 : 0;
		gradientFactor += _DecalGradientMode == 2 && decalInput.positionDS.y < 0 ? 1 : 0;
		gradientFactor = saturate(gradientFactor);

		alphaModifier *= gradientFactor;
    #endif

	if (_SubstractAlphaFlag > 0)
	{
		albedoAlpha.a = saturate(albedoAlpha.a - (1 - _BaseColor.a));
	}
	else
	{
		albedoAlpha.a *= _BaseColor.a;
	}

	albedoAlpha.a = albedoAlpha.a * _AlphaScale;

	#if defined(RADIAL_ALPHA)
		float radialGrad = saturate(pow(length(decalInput.positionDS.xz * 2.0 - 1.0), _RadialAlphaGradientPower));
		radialGrad = _RadialAlphaGradientStart * (1 - radialGrad);

		if (_RadialAlphaSubstract > 0)
		{
			albedoAlpha.a = albedoAlpha.a - (1 - saturate(radialGrad));
		}
		else
		{
			albedoAlpha.a = albedoAlpha.a * radialGrad;
		}
	#endif

	albedoAlpha.a = saturate(albedoAlpha.a * alphaModifier);

	if (_Cutoff > 0)
	{
		clip(albedoAlpha.a - _Cutoff);
	}

	float3 normalWS = input.normalWS;
	#ifdef _NORMALMAP
        float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D_GRAD(_BumpMap, sampler_BumpMap, uv0, decalInput.textureGradients.xy * _BaseMap_ST.xy, decalInput.textureGradients.zw * _BaseMap_ST.xy), _BumpScale);
		normalTS = normalize(normalTS);
		normalWS = TransformTangentToWorld(normalTS, float3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
    #endif

	//normalWS = lerp(decalInput.normalWS, normalWS, albedoAlpha.a);

    float4 masks = float4(_Roughness, 1, _Metallic, 0);

    #ifdef _MASKSMAP
        masks *= SAMPLE_TEXTURE2D_GRAD(_MasksMap, sampler_MasksMap, uv0, decalInput.textureGradients.xy * _BaseMap_ST.xy, decalInput.textureGradients.zw * _BaseMap_ST.xy);
    #endif

    #ifdef _EMISSION
		float3 emission = lerp(albedoAlpha.rgb, _EmissionColor.rgb, _EmissionColorFactor);
		#ifdef _EMISSIONMAP
			float2 uvEmission = TransformUv(decalInput, _EmissionMap_ST, _EmissionUVSpeed.xy) + uvNoised;
			float4 emissionSample = SampleDecalTextureGrad(TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap), uvEmission, decalInput.textureGradients.xyzw * _EmissionMap_ST.xyxy);
			if (_EmissionMapUsage > 0)
			{
				emission.rgb *= emissionSample.a * albedoAlpha.a;
				albedoAlpha.rgb = lerp(albedoAlpha.rgb, 0, saturate(emissionSample.a * _EmissionAlbedoSuppression));
			}
			else
			{
				emission.rgb *= emissionSample.rgb * albedoAlpha.a;
				albedoAlpha.rgb = lerp(albedoAlpha.rgb, 0, saturate(_EmissionAlbedoSuppression * dot(emissionSample.rgb, float3(.3, .59, .11))));
			}
		#else
			emission *= masks.g * albedoAlpha.a;
			albedoAlpha.rgb = lerp(albedoAlpha.rgb, 0, saturate(masks.g * _EmissionAlbedoSuppression));
		#endif
		
		emission *= max(0, _EmissionColorScale.xxx);
		emission = SRGBToLinear(emission);
    #else
        float3 emission = 0;
    #endif

    // convert perceptual roughness to perceptual smoothness
    masks.r = 1.0 - masks.r;

	#ifdef DEFERRED_ON
		//float4 gBufferNormalAndSmoothness = float4(decalInput.normalWS.xyz, decalInput.smoothness);
		//float4 decalNormalAndSmoothness = float4(normalWS.xyz, masks.r);
		//gBufferNormalAndSmoothness = lerp(gBufferNormalAndSmoothness, decalNormalAndSmoothness, albedoAlpha.a);
		//gBufferNormalAndSmoothness.rgb = normalize(gBufferNormalAndSmoothness.rgb);
		//gBufferNormalAndSmoothness.rgb = EncodeNormal(gBufferNormalAndSmoothness.rgb);
		//_CameraNormalsUAV[input.positionCS.xy] = gBufferNormalAndSmoothness;

		//float4 gBufferAlbedoAndMetallic = _CameraAlbedoUAV[input.positionCS.xy];
		//float4 decalAlbedoAndMetallic = float4(albedoAlpha.rgb, masks.b);
		//gBufferAlbedoAndMetallic = lerp(gBufferAlbedoAndMetallic, decalAlbedoAndMetallic, albedoAlpha.a);
		//_CameraAlbedoUAV[input.positionCS.xy] = gBufferAlbedoAndMetallic;
	#endif
	
	// InputData initialization
	InputData inputData = (InputData)0;
	inputData.positionWS = decalInput.positionWS;
	inputData.positionSS = input.positionCS.xy;
	inputData.normalWS = normalWS;
	inputData.viewDirectionWS = normalize(_WorldSpaceCameraPos - decalInput.positionWS);
	inputData.linearDepth = LinearEyeDepth(decalInput.deviceDepth);
	inputData.fogCoord = ComputeFogFactor(inputData.linearDepth);
	inputData.bakedGI = LOAD_TEXTURE2D(_CameraBakedGIRT, inputData.positionSS).rgb;
	inputData.shadowMask = LOAD_TEXTURE2D(_CameraShadowmaskRT, inputData.positionSS);
	float linearDepth01 = (inputData.linearDepth - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
	inputData.depthSliceIndex = linearDepth01 * _Clusters.z;
	inputData.clusterUv = uint3(inputData.positionSS * _ScreenSize.zw * _Clusters.xy, inputData.depthSliceIndex);

	#ifdef DECALS_LIGHTING_ON
		float4 color = FragmentPBR(
			inputData,
			albedoAlpha.rgb,
			masks.b, // metallic
			0, // specular
			masks.r, // smoothness
			1, // occlusion
			emission.rgb, // emission
			albedoAlpha.a, // alpha
			0, // translucency
			0, // wrapDiffuseFactor
			0 // materialFeatures
			);
	#else
		float4 color = albedoAlpha;
		color.rgb += emission;
	#endif

	#ifdef SUPPORT_FOG_OF_WAR
		ApplyFogOfWarFactor(fowFactor, color.rgb);
	#endif

	FinalColorOutput(color);

	// туман нужно миксовать после перевода в Gamma-space, потому что пост-процессный туман работает через аддитивный блендинг в гамме (т.е. его невозможно перевести в линеар)
	// поэтому делаем все в гамме
	color.rgb = MixFog(color.rgb, inputData.fogCoord);

	#ifdef DEFERRED_ON
		colorOutput = color;
		normal.rgb = normalWS;
		normal.a = color.a;
		smoothnessAndMetallic = float4(masks.r, masks.b, 0, color.a);
	#else
		return color;
	#endif	
}

void DecalFragmentStencil(Varyings IN, out float4 albedo : SV_Target0)
{
    albedo = 0;
}

#ifndef FULL_SCREEN_DECALS
Varyings SceneSelectionVertex(Attributes IN)
{
    Varyings OUT = (Varyings) 0;

    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_TRANSFER_INSTANCE_ID(IN, OUT);

    OUT.positionCS = TransformObjectToHClip(IN.vertex.xyz);
    // деление не интерполируется, поэтому переносим его в пиксельный шейдер
    //OUT.cameraRay = CreateRay(OUT.positionCS.xy / OUT.positionCS.w);
    OUT.cameraRay = OUT.positionCS.xyw;

    return OUT;
}

float _ObjectId;
float _PassValue;

float4 SceneSelectionFragment(Varyings input) : SV_Target0
{
	return float4(_ObjectId, _PassValue, 1.0, 1.0);
}
#endif

#endif // OWLCAT_DECAL_PASS_INCLUDED
