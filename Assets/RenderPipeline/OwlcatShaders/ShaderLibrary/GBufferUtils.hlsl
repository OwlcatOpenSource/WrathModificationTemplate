#ifndef OWLCAT_GBUFFER_UTILS_INCLUDED
#define OWLCAT_GBUFFER_UTILS_INCLUDED

#ifdef DEFERRED_ON
	struct GBufferOutput
	{
		float4 albedo			: SV_Target0;
		float4 normal			: SV_Target1;
		float4 emission			: SV_Target2;
		float4 bakedGI			: SV_Target3;
		float4 shadowmask		: SV_Target4;
		float4 translucency		: SV_Target5;
	};
#else
	struct GBufferOutput
	{
		float4 normal			: SV_Target0;
		float4 bakedGI			: SV_Target1;
		float4 shadowmask		: SV_Target2;
	};
#endif

GBufferOutput EncodeGBuffer(float3 albedo, float3 normal, float smoothness, float metallic, float3 emission, float3 bakedGI, float4 shadowmask, float3 translucency, uint materialFeatures)
{
	GBufferOutput output = (GBufferOutput)0;
	output.normal = float4(EncodeNormal(normal), smoothness);
	output.bakedGI = float4(bakedGI.rgb, 0);
	output.shadowmask = shadowmask;
	#if defined(DEFERRED_ON)
		output.albedo = float4(albedo, metallic);
		output.emission = float4(emission, 0);
		output.translucency = float4(translucency, PackByte(materialFeatures));
	#endif

	return output;
}

void DecodeGBuffer(uint2 positionSS, float3 cameraRay, out InputData inputData, out SurfaceData surfaceData, out uint materialFeatures)
{
	float4 albedoAndMetallic = LOAD_TEXTURE2D(_CameraAlbedoRT, positionSS.xy);
	float4 translucencyAndMaterialFeatures = LOAD_TEXTURE2D(_CameraTranslucencyRT, positionSS.xy);
	materialFeatures = UnpackByte(translucencyAndMaterialFeatures.a);
	
	float4 shadowmask = 1;
	if (HasFlag(materialFeatures, MATERIALFEATURES_SHADOWMASK))
	{
		shadowmask = LOAD_TEXTURE2D(_CameraShadowmaskRT, positionSS.xy);
	}

	float deviceDepth = LOAD_TEXTURE2D(_CameraDepthRT, positionSS.xy).x;
	float4 normalAndSmoothness = DecodeNormalAndSmoothness(LOAD_TEXTURE2D(_CameraNormalsRT, positionSS.xy));

	#if defined(DEFERRED_INTERPOLATED_POSITION_RECONSTRUCTION) && !defined(SHADER_API_PS4)
		float3 positionWS = ReconstructPositionFromDeviceDepth(cameraRay, _WorldSpaceCameraPos, deviceDepth);
	#else
		float3 positionWS = ComputeWorldSpacePosition(positionSS.xy * _ScreenSize.zw + _ScreenSize.zw * .5, deviceDepth, _InvCameraViewProj);
	#endif
	float linearDepth = LinearEyeDepth(deviceDepth);
	float linearDepth01 = (linearDepth - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
	float3 viewDir = normalize(_WorldSpaceCameraPos - positionWS);

	// InputData initialization
	inputData.positionWS = positionWS;
	inputData.positionSS = positionSS.xy;
	inputData.normalWS = normalize(normalAndSmoothness.xyz);
	inputData.viewDirectionWS = viewDir;
	inputData.linearDepth = linearDepth;
	inputData.fogCoord = ComputeFogFactor(linearDepth);
	inputData.bakedGI = LOAD_TEXTURE2D(_CameraBakedGIRT, positionSS.xy).rgb;
	inputData.shadowMask = shadowmask;
	inputData.depthSliceIndex = linearDepth01 * _Clusters.z;
	inputData.clusterUv = uint3(positionSS.xy * _ScreenSize.zw * _Clusters.xy, inputData.depthSliceIndex);

	surfaceData.albedo = albedoAndMetallic.rgb;
	surfaceData.specular = 0;
	surfaceData.metallic = albedoAndMetallic.a;
	surfaceData.smoothness = normalAndSmoothness.a;
	surfaceData.normalTS = 0;
	surfaceData.emission = 0;
	surfaceData.occlusion = 1;
	surfaceData.alpha = 1;
	surfaceData.translucency = translucencyAndMaterialFeatures.rgb;
	surfaceData.wrapDiffuseFactor = 0;
}

#endif // OWLCAT_GBUFFER_UTILS_INCLUDED
