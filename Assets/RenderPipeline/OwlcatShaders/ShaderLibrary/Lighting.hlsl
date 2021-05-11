#ifndef OWLCAT_LIGHTING_INCLUDED
#define OWLCAT_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Core.hlsl"
#include "Shadows/Shadow.hlsl"

// 15 degrees
#define TRANSMISSION_WRAP_ANGLE (PI/12)
#define TRANSMISSION_WRAP_LIGHT cos(PI/2 - TRANSMISSION_WRAP_ANGLE)

// If lightmap is not defined than we evaluate GI (ambient + probes) from SH
// We might do it fully or partially in vertex to save shader ALU
#if !defined(LIGHTMAP_ON)
    // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
    #if defined(SHADER_API_GLES) || !defined(_NORMALMAP)
        // Evaluates SH fully in vertex
        #define EVALUATE_SH_VERTEX
    #elif !SHADER_HINT_NICE_QUALITY
        // Evaluates L2 SH in vertex and L0L1 in pixel
        #define EVALUATE_SH_MIXED
    #endif
        // Otherwise evaluate SH fully per-pixel
#endif


#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, dynamicLightmapUV, dynamicLightmapScaleOffset, OUT) OUT.xyzw = float4(lightmapUV.xy * lightmapScaleOffset.xy + lightmapScaleOffset.zw, dynamicLightmapUV.xy * dynamicLightmapScaleOffset.xy + dynamicLightmapScaleOffset.zw);
    #define OUTPUT_SH(normalWS, OUT)
#else
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, dynamicLightmapUV, dynamicLightmapScaleOffset, OUT)
    #define OUTPUT_SH(normalWS, OUT) OUT.xyz = SampleSHVertex(normalWS)
#endif

///////////////////////////////////////////////////////////////////////////////
//                          Light Helpers                                    //
///////////////////////////////////////////////////////////////////////////////

// Abstraction over Light shading data.
struct Light
{
    float3 direction;
    float3 diffuseDirection;
    float3 specularDirection;
    float3 color;
    float attenuation;
    float4 shadowMaskSelector;
    int shadowIndex;
	float shadowStrength;
    float solidAngle;
};

int GetPerObjectLightIndex(int index)
{
    // The following code is more optimal than indexing unity_4LightIndices0.
    // Conditional moves are branch free even on mali-400
    float2 lightIndex2 = (index < 2.0h) ? unity_LightIndices[0].xy : unity_LightIndices[0].zw;
    float i_rem = (index < 2.0h) ? index : index - 2.0h;
    return (i_rem < 1.0h) ? lightIndex2.x : lightIndex2.y;
}

///////////////////////////////////////////////////////////////////////////////
//                        Attenuation Functions                               /
///////////////////////////////////////////////////////////////////////////////

// Matches Unity Vanila attenuation
// Attenuation smoothly decreases to light range.
float DistanceAttenuation(float distanceSqr, float2 distanceAttenuation, float innerRadius, bool legacyAttenuation)
{
    UNITY_BRANCH
    if (legacyAttenuation)
    {
        float normalizedSqrDist = distanceSqr * distanceAttenuation.x;
        innerRadius *= distanceAttenuation.x;
        float zeroFadeStart = innerRadius * innerRadius;
        float lerpFactor = normalizedSqrDist > zeroFadeStart;
        float lightAtten = 1.0 / (1.0 + distanceSqr * distanceAttenuation.y);
	    lightAtten *= lerp(1, 1 - (normalizedSqrDist - zeroFadeStart) / (1 - zeroFadeStart), lerpFactor);
        lightAtten *= normalizedSqrDist > 1 ? 0 : 1;

        return lightAtten;
	}
    else
    {
        // We use a shared distance attenuation for additional directional and puctual lights
        // for directional lights attenuation will be 1
        float lightAtten = rcp(distanceSqr);
        float smoothFactor = 1;

        UNITY_BRANCH
        if (innerRadius <= 0)
        {
            // Use the smoothing factor also used in the Unity lightmapper.
            float factor = distanceSqr * distanceAttenuation.x;
            smoothFactor = saturate(1.0 - factor * factor);
            smoothFactor = smoothFactor * smoothFactor;
        }
        else
        {
            // We need to smoothly fade attenuation to light range. We start fading linearly at 80% of light range
            // Therefore:
            // fadeDistance = (0.8 * 0.8 * lightRangeSq)
            // smoothFactor = (lightRangeSqr - distanceSqr) / (lightRangeSqr - fadeDistance)
            // We can rewrite that to fit a MAD by doing
            // distanceSqr * (1.0 / (fadeDistanceSqr - lightRangeSqr)) + (-lightRangeSqr / (fadeDistanceSqr - lightRangeSqr)
            // distanceSqr *        distanceAttenuation.y            +             distanceAttenuation.z
            smoothFactor = saturate(distanceSqr * distanceAttenuation.x + distanceAttenuation.y);
        }

        return lightAtten * smoothFactor;
	}
}

float AngleAttenuation(float3 spotDirection, float3 lightDirection, float2 spotAttenuation)
{
    // Spot Attenuation with a linear falloff can be defined as
    // (SdotL - cosOuterAngle) / (cosInnerAngle - cosOuterAngle)
    // This can be rewritten as
    // invAngleRange = 1.0 / (cosInnerAngle - cosOuterAngle)
    // SdotL * invAngleRange + (-cosOuterAngle * invAngleRange)
    // SdotL * spotAttenuation.x + spotAttenuation.y

    // If we precompute the terms in a MAD instruction
    float SdotL = dot(spotDirection, lightDirection);
    float atten = saturate(SdotL * spotAttenuation.x + spotAttenuation.y);
    return atten * atten;
}

///////////////////////////////////////////////////////////////////////////////
//                      Light Abstraction                                    //
///////////////////////////////////////////////////////////////////////////////
float4 DecodeShadowmaskSelector(uint packedShadowmaskSelector)
{
    if (packedShadowmaskSelector == 0)
    {
        return float4(-1, 0, 0, 0);
	}

    return float4((packedShadowmaskSelector & (1 << 0)) != 0, (packedShadowmaskSelector & (1 << 1)) != 0, (packedShadowmaskSelector & (1 << 2)) != 0, (packedShadowmaskSelector & (1 << 3)) != 0);
}

Light GetDirectionalLight(int index)
{
    Light light = (Light) 0;
	LightData ld = _LightDataBuffer[index];
    light.direction = ld.position;
    light.diffuseDirection = light.direction;
    light.specularDirection = light.direction;
    light.attenuation = 1;
    light.shadowMaskSelector = DecodeShadowmaskSelector(ld.shadowMaskSelector);
    light.color = ld.color.rgb;
    light.shadowIndex = ld.shadowDataIndex;
	light.shadowStrength = ld.shadowStrength;
    return light;
}

Light GetPunctualLight(int index, float3 positionWS, float3 normalWS, float3 viewDirectionWS)
{
	LightData ld = _LightDataBuffer[index];
    float3 lightPositionWS = ld.position;
    float4 distanceAndSpotAttenuation = ld.attenuations;
    float3 spotDirection = ld.spotDir;

    float3 lightVector = lightPositionWS - positionWS;
    float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);
    float rcpDist = rsqrt(distanceSqr);
    
    float3 lightDirection = float3(lightVector * rcpDist);
    float attenuation = DistanceAttenuation(distanceSqr, distanceAndSpotAttenuation.xy, ld.innerRadius, (ld.flags & (1u << 0)) != 0);
    attenuation *= AngleAttenuation(spotDirection.xyz, lightDirection, distanceAndSpotAttenuation.zw);

    Light light = (Light) 0;
    light.direction = lightDirection;
    light.diffuseDirection = normalize(lightVector + normalWS * ld.innerRadius);
    light.attenuation = attenuation;
    light.color = ld.color.rgb;
    light.shadowIndex = ld.shadowDataIndex;
    light.shadowMaskSelector = DecodeShadowmaskSelector(ld.shadowMaskSelector);
	light.shadowStrength = ld.shadowStrength;

    #ifndef _SPECULARHIGHLIGHTS_OFF
        if (ld.innerRadius > 0 && (ld.flags & (1u << 1)) != 0)
        {
            float3 lr = reflect(viewDirectionWS, normalWS);
		    float3 dir = lr * rcp(rcpDist) + lightVector;
		    float len = length(dir);
		    light.specularDirection = normalize(lightVector - dir * saturate(ld.innerRadius / len));
            light.solidAngle = ld.innerRadius / rcp(rcpDist) * .5;
        }
        else
        {
            light.specularDirection = light.direction;
		}
    #else
        light.specularDirection = light.direction;
    #endif

    return light;
}

///////////////////////////////////////////////////////////////////////////////
//                         BRDF Functions                                    //
///////////////////////////////////////////////////////////////////////////////

#define kDieletricSpec float4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

struct BRDFData
{
    float3 diffuse;
    float3 specular;
    float perceptualRoughness;
    float roughness;
    float roughness2;
    float grazingTerm;

    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    float normalizationTerm; // roughness * 4.0 + 2.0
    float roughness2MinusOne; // roughness² - 1.0
	float3 translucency;
    float wrapDiffuseFactor;
};

float ReflectivitySpecular(float3 specular)
{
    #if defined(SHADER_API_GLES)
        return specular.r; // Red channel - because most metals are either monocrhome or with redish/yellowish tint
    #else
        return max(max(specular.r, specular.g), specular.b);
    #endif
}

float OneMinusReflectivityMetallic(float metallic)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in kDieletricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    float oneMinusDielectricSpec = kDieletricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

inline void InitializeBRDFData(float3 albedo, float metallic, float3 specular, float smoothness, float alpha, float3 translucency, float wrapDiffuseFactor, out BRDFData outBRDFData)
{
    #ifdef _SPECULAR_SETUP
        float reflectivity = ReflectivitySpecular(specular);
        float oneMinusReflectivity = 1.0 - reflectivity;

        outBRDFData.diffuse = albedo * (float3(1.0h, 1.0h, 1.0h) - specular);
        outBRDFData.specular = specular;
    #else

        float oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
        float reflectivity = 1.0 - oneMinusReflectivity;

        outBRDFData.diffuse = albedo * oneMinusReflectivity;
        outBRDFData.specular = lerp(kDieletricSpec.rgb, albedo, metallic);
    #endif

    outBRDFData.grazingTerm = saturate(smoothness + reflectivity);
    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
    outBRDFData.roughness = PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness);

    outBRDFData.roughness2 = outBRDFData.roughness * outBRDFData.roughness;

    outBRDFData.normalizationTerm = outBRDFData.roughness * 4.0h + 2.0h;
    outBRDFData.roughness2MinusOne = outBRDFData.roughness2 - 1.0h;

	// домножаем в конце шейдера
    /*#ifdef _ALPHAPREMULTIPLY_ON
        outBRDFData.diffuse *= alpha;
        alpha = alpha * oneMinusReflectivity + reflectivity;
    #endif*/

	outBRDFData.translucency = translucency;
    outBRDFData.wrapDiffuseFactor = wrapDiffuseFactor;
}

float3 EnvironmentBRDF(BRDFData brdfData, float3 indirectDiffuse, float3 indirectSpecular, float fresnelTerm)
{
	float3 c = indirectDiffuse * brdfData.diffuse;
	#ifdef DEBUG_DISPLAY
		if (_DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTION_PROBES)
		{
			c = 0;
		}
	#endif
    
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
    return c;
}

// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF [Modified] GGX
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
float3 DirectBDRF(BRDFData brdfData, float3 normalWS, float3 lightDirectionWS, float3 viewDirectionWS, float solidAngle)
{
    #ifndef _SPECULARHIGHLIGHTS_OFF
        float3 halfDir = SafeNormalize(lightDirectionWS + viewDirectionWS);

        float NoH = saturate(dot(normalWS, halfDir));
        float LoH = saturate(dot(lightDirectionWS, halfDir));

        // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
        // BRDFspec = (D * V * F) / 4.0
        // D = roughness² / ( NoH² * (roughness² - 1) + 1 )²
        // V * F = 1.0 / ( LoH² * (roughness + 0.5) )
        // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
        // https://community.arm.com/events/1155

        // Final BRDFspec = roughness² / ( NoH² * (roughness² - 1) + 1 )² * (LoH² * (roughness + 0.5) * 4.0)
        // We further optimize a few light invariant terms
        // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
        float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001;

        float LoH2 = LoH * LoH;
        float specularTerm = brdfData.roughness2 / ((d * d) * max(0.1, LoH2) * brdfData.normalizationTerm);
        float distributionNormalization = max(.001, brdfData.roughness / saturate(brdfData.roughness + solidAngle * solidAngle));
        specularTerm *= distributionNormalization * distributionNormalization;

        // on mobiles (where half actually means something) denominator have risk of overflow
        // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
        // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
        #if defined (SHADER_API_MOBILE)
            specularTerm = specularTerm - HALF_MIN;
            specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
        #endif

        float3 color = specularTerm * brdfData.specular + brdfData.diffuse;
        return color;
    #else
        return brdfData.diffuse;
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                      Global Illumination                                  //
///////////////////////////////////////////////////////////////////////////////

// Samples SH L0, L1 and L2 terms
float3 SampleSH(float3 normalWS)
{
    // LPPV is not supported in Ligthweight Pipeline
    real4 SHCoefficients[7];
    SHCoefficients[0] = unity_SHAr;
    SHCoefficients[1] = unity_SHAg;
    SHCoefficients[2] = unity_SHAb;
    SHCoefficients[3] = unity_SHBr;
    SHCoefficients[4] = unity_SHBg;
    SHCoefficients[5] = unity_SHBb;
    SHCoefficients[6] = unity_SHC;

    return max(float3(0, 0, 0), SampleSH9(SHCoefficients, normalWS));
}

// SH Vertex Evaluation. Depending on target SH sampling might be
// done completely per vertex or mixed with L2 term per vertex and L0, L1
// per pixel. See SampleSHPixel
float3 SampleSHVertex(float3 normalWS)
{
    #if defined(EVALUATE_SH_VERTEX)
        return max(float3(0, 0, 0), SampleSH(normalWS));
    #elif defined(EVALUATE_SH_MIXED)
        // no max since this is only L2 contribution
        return SHEvalLinearL2(normalWS, unity_SHBr, unity_SHBg, unity_SHBb, unity_SHC);
    #endif

    // Fully per-pixel. Nothing to compute.
    return float3(0.0, 0.0, 0.0);
}

// SH Pixel Evaluation. Depending on target SH sampling might be done
// mixed or fully in pixel. See SampleSHVertex
float3 SampleSHPixel(float3 L2Term, float3 normalWS)
{
    #if defined(EVALUATE_SH_VERTEX)
        return L2Term;
    #elif defined(EVALUATE_SH_MIXED)
        float3 L0L1Term = SHEvalLinearL0L1(normalWS, unity_SHAr, unity_SHAg, unity_SHAb);
        return max(float3(0, 0, 0), L2Term + L0L1Term);
    #endif

    // Default: Evaluate SH fully per-pixel
    return SampleSH(normalWS);
}

// Sample baked lightmap. Non-Direction and Directional if available.
// Realtime GI is not supported.
float3 SampleLightmap(float2 lightmapUV, float2 dynamicLightmapUV, float3 normalWS)
{
    #ifdef UNITY_LIGHTMAP_FULL_HDR
        bool encodedLightmap = false;
    #else
        bool encodedLightmap = true;
    #endif

    float4 decodeInstructions = float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0h, 0.0h);

    // The shader library sample lightmap functions transform the lightmap uv coords to apply bias and scale.
    // However, lightweight pipeline already transformed those coords in vertex. We pass float4(1, 1, 0, 0) and
    // the compiler will optimize the transform away.
    float4 transformCoords = float4(1, 1, 0, 0);

	float3 bakeDiffuseLighting = float3(0, 0, 0);

	#ifdef LIGHTMAP_ON
		#ifdef DIRLIGHTMAP_COMBINED
			bakeDiffuseLighting += SampleDirectionalLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap),
				TEXTURE2D_ARGS(unity_LightmapInd, samplerunity_Lightmap),
				lightmapUV, transformCoords, normalWS, encodedLightmap, decodeInstructions);
		#else
			bakeDiffuseLighting += SampleSingleLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightmapUV, transformCoords, encodedLightmap, decodeInstructions);
		#endif
	#endif

	#ifdef DYNAMICLIGHTMAP_ON
		#ifdef DIRLIGHTMAP_COMBINED
			bakeDiffuseLighting += SampleDirectionalLightmap(TEXTURE2D_ARGS(unity_DynamicLightmap, samplerunity_DynamicLightmap),
                                                        TEXTURE2D_ARGS(unity_DynamicDirectionality, samplerunity_DynamicLightmap),
                                                        dynamicLightmapUV, transformCoords, normalWS, false, decodeInstructions);
		#else
			bakeDiffuseLighting += SampleSingleLightmap(TEXTURE2D_ARGS(unity_DynamicLightmap, samplerunity_DynamicLightmap), dynamicLightmapUV, transformCoords, false, decodeInstructions);
		#endif
	#endif

	return bakeDiffuseLighting;
}

float4 SampleShadowmask(float4 sampleData)
{
	#if defined(INDIRECT_INSTANCING)
		IndirectInstanceData instData = _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID];
		return instData.shadowmask;
	#else
		#if !defined(INDIRECT_INSTANCING)
			#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
				#ifdef SHADOWS_SHADOWMASK
					return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, sampleData.xy); // Reuse sampler from Lightmap
				#endif
			#endif
		#endif
	#endif

	return float4(0,0,0,0);
}

// We either sample GI from baked lightmap or from probes.
// If lightmap: sampleData.xy = lightmapUV
// If probe: sampleData.xyz = L2 SH terms
void SampleGI(float4 sampleData, float3 positionWS, float3 normalWS, out float3 bakedGI, out float4 shadowMask)
{
	shadowMask = 1;
	#if defined(INDIRECT_INSTANCING)
		IndirectInstanceData instData = _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID];
		//bakedGI = instData.lightmapColor.rgb + instData.realtimeLightmapColor.rgb;
		// временная заглушка
		bakedGI = _LightProbesBuffer[GET_INDIRECT_INSTANCE_ID].rgb;// SampleSHPixel(sampleData.xyz, normalWS);
		shadowMask = instData.shadowmask;
	#else
		#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
			bakedGI = SampleLightmap(sampleData.xy, sampleData.zw, normalWS);

			shadowMask = SampleShadowmask(sampleData);
		#else
            if (unity_ProbeVolumeParams.x == 0.0)
            {
			    // If lightmap is not enabled we sample GI from SH
			    bakedGI = SampleSHPixel(sampleData.xyz, normalWS);
            }
            else
            {
                bakedGI = SampleProbeVolumeSH4(TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH), positionWS, normalWS, GetProbeVolumeWorldToObject(),
                    unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z, unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz);
            }
		#endif
	#endif
}

float3 BoxProjectedCubemapDirection(float3 reflectVector, float3 positionWS)
{
	float3 nrdir = normalize(reflectVector);
	float3 rbmax = (unity_SpecCube0_BoxMax.xyz - positionWS) / nrdir;
	float3 rbmin = (unity_SpecCube0_BoxMin.xyz - positionWS) / nrdir;
	float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;
	float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
	positionWS -= unity_SpecCube0_ProbePosition.xyz;
	reflectVector = positionWS + nrdir * fa;
	return reflectVector;
}

float3 GlossyEnvironmentReflection(float3 reflectVector, float3 positionWS, float perceptualRoughness, float occlusion)
{
    #if !defined(_ENVIRONMENTREFLECTIONS_OFF) && !defined(DEFERRED_ON)
        float mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
        #ifdef UNITY_SPECCUBE_BOX_PROJECTION
            reflectVector = BoxProjectedCubemapDirection(reflectVector, positionWS);
        #endif

        float4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);

        #if !defined(UNITY_USE_NATIVE_HDR)
            float3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
        #else
            float3 irradiance = encodedIrradiance.rbg;
        #endif

        return irradiance * occlusion;
    #endif // GLOSSY_REFLECTIONS

    return 0;//_GlossyEnvironmentColor.rgb * occlusion;
}

float3 GlobalIllumination(BRDFData brdfData, float3 bakedGI, float occlusion, float3 positionWS, float3 normalWS, float3 viewDirectionWS)
{
	float3 reflectVector = reflect(-viewDirectionWS, normalWS);
	float3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, occlusion);

	float fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

	float3 indirectDiffuse = bakedGI * occlusion;

    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}

void MixRealtimeAndBakedGI(inout Light light, float3 normalWS, inout float3 bakedGI, float4 shadowMask)
{
    #if defined(_MIXED_LIGHTING_SUBTRACTIVE) && defined(LIGHTMAP_ON)
        bakedGI = SubtractDirectMainLightFromLightmap(light, normalWS, bakedGI);
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                      Lighting Functions                                   //
///////////////////////////////////////////////////////////////////////////////
float3 LightingLambert(float3 lightColor, float3 lightDir, float3 normal)
{
    float NdotL = saturate(dot(normal, lightDir));
    return lightColor * NdotL;
}

float3 LightingSpecular(float3 lightColor, float3 lightDir, float3 normal, float3 viewDir, float4 specular, float smoothness)
{
    float3 halfVec = SafeNormalize(lightDir + viewDir);
    float NdotH = saturate(dot(normal, halfVec));
    float modifier = pow(NdotH, smoothness);
    float3 specularReflection = specular.rgb * modifier;
    return lightColor * specularReflection;
}

float3 EvalTranslucency(float3 normalWS, float3 lightDirectionWS, float3 viewDirectionWS, float3 translucency, float3 lightColor, float lightAttenuation, float wrapDiffuseFactor, uint materialFeatures)
{
	// simple translucency (not PBR) https://en.wikibooks.org/wiki/GLSL_Programming/Unity/Translucent_Surfaces
	// https://www.gdcvault.com/play/1014538/Approximating-Translucency-for-a-Fast
	// https://habr.com/ru/post/337370/
	float3 transLight = normalize(lightDirectionWS + normalWS);
	float transForward = max(0.0, dot(viewDirectionWS, -transLight));
	// lerp optimization
	float transNdotL = saturate(dot(-normalWS, lightDirectionWS));
	#if defined(DEFERRED_ON)
        if (HasFlag(materialFeatures, MATERIALFEATURES_WRAP_DIFFUSE))
		{
			transNdotL = ComputeWrappedDiffuseLighting(transNdotL, TRANSMISSION_WRAP_LIGHT);
		}
	#else
        #if defined(WRAP_DIFFUSE)
            if (wrapDiffuseFactor > 0)
            {
		        transNdotL = ComputeWrappedDiffuseLighting(transNdotL, wrapDiffuseFactor);
            }
        #endif
	#endif
	return lightAttenuation * lightColor * (transForward + transNdotL) * translucency;
}

float3 LightingPhysicallyBased(BRDFData brdfData, Light light, float3 normalWS, float3 viewDirectionWS, uint materialFeatures)
{
    /*float NdotL = saturate(dot(normalWS, lightDirectionWS));
    float3 radiance = lightColor * (lightAttenuation * NdotL);
    return DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;*/

	float NdotL = dot(normalWS, light.diffuseDirection);

	float3 radiance = 0;// lightColor * (lightAttenuation * saturate(NdotL));
    
	#ifdef DEFERRED_ON
		if (HasFlag(materialFeatures, MATERIALFEATURES_TRANSLUCENT))
		{
			radiance += EvalTranslucency(normalWS, light.diffuseDirection, viewDirectionWS, brdfData.translucency, light.color, light.attenuation, brdfData.wrapDiffuseFactor, materialFeatures);
		}

		if (HasFlag(materialFeatures, MATERIALFEATURES_WRAP_DIFFUSE))
		{
			NdotL = ComputeWrappedDiffuseLighting(NdotL, TRANSMISSION_WRAP_LIGHT);
		}
	#else
		// simple translucency (not PBR) https://en.wikibooks.org/wiki/GLSL_Programming/Unity/Translucent_Surfaces
		// https://www.gdcvault.com/play/1014538/Approximating-Translucency-for-a-Fast
		// https://habr.com/ru/post/337370/
		#if defined(_TRANSLUCENT)
			radiance += EvalTranslucency(normalWS, light.diffuseDirection, viewDirectionWS, brdfData.translucency, light.color, light.attenuation, brdfData.wrapDiffuseFactor, materialFeatures);
		#endif

        #if defined(WRAP_DIFFUSE)
		    if (brdfData.wrapDiffuseFactor > 0)
		    {
			    NdotL = ComputeWrappedDiffuseLighting(NdotL, brdfData.wrapDiffuseFactor);
		    }
        #endif
	#endif

	radiance += light.color * (light.attenuation * saturate(NdotL));

    #ifdef DEBUG_DISPLAY
        if (_DebugLightingMode == DEBUGLIGHTINGMODE_DIFFUSE)
        {
            return radiance;
        }
    #endif
    
    return DirectBDRF(brdfData, normalWS, light.specularDirection, viewDirectionWS, light.solidAngle) * radiance;
}

float3 VertexLighting(float3 positionWS, float3 normalWS)
{
    float3 vertexLightColor = float3(0.0, 0.0, 0.0);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        int pixelLightCount = GetAdditionalLightsCount();
        for (int i = 0; i < pixelLightCount; ++i)
        {
            Light light = GetAdditionalLight(i, positionWS);
            float3 lightColor = light.color * light.distanceAttenuation;
            vertexLightColor += LightingLambert(lightColor, light.direction, normalWS);
        }
    #endif

    return vertexLightColor;
}

///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////
void EvalLighting(inout float3 color, BRDFData brdfData, InputData inputData, Light light, bool directionalLight, uint materialFeatures)
{
    #ifdef DEBUG_DISPLAY
        switch (_DebugLightingMode)
        {
            case DEBUGLIGHTINGMODE_NONE:
            case DEBUGLIGHTINGMODE_DIFFUSE:
            case DEBUGLIGHTINGMODE_SPECULAR:
                {
                    color += LightingPhysicallyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, materialFeatures);
                }
                break;
            case DEBUGLIGHTINGMODE_VISUALIZE_CASCADE:
                {
                    const float3 s_CascadeColors[] =
                    {
                        float3(1.0, 0.0, 0.0),
                        float3(0.0, 1.0, 0.0),
                        float3(0.0, 0.0, 1.0),
                        float3(1.0, 1.0, 0.0),
                        float3(1.0, 1.0, 1.0)
                    };

                    if (directionalLight)
                    {
                        int cascadeIndex = ComputeCascadeIndex(_ShadowDataBuffer[0], inputData.positionWS);
                        light.color = s_CascadeColors[cascadeIndex];
                    }

                    color += LightingPhysicallyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, materialFeatures);
                }
                break;
            case DEBUGLIGHTINGMODE_BAKED_GI:
                {
                    color = inputData.bakedGI;
                }
                break;
            case DEBUGLIGHTINGMODE_SHADOWMASK:
                {
                    color += (light.shadowMaskSelector.x >= 0.0) ? dot(inputData.shadowMask, light.shadowMaskSelector) : 0;
                }
                break;
            case DEBUGLIGHTINGMODE_SHADOWMASK_RAW:
                {
                    color = inputData.shadowMask.rgb;
                }
                break;
            case DEBUGLIGHTINGMODE_LIGHT_ATTENUATION:
                {
                    color += light.attenuation;
                }
                break;
        }
    #else
        color += LightingPhysicallyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, materialFeatures);
    #endif
}

void PunctualLighting(inout float3 color, BRDFData brdfData, InputData inputData, Light light, float shadowFade, uint materialFeatures)
{
	float shadow = 1.0;
	float shadowMask = 1.0f;
	#if defined(SHADOWS_SHADOWMASK) && (defined(DEFERRED_ON) || defined(LIGHTMAP_ON)) || defined(INDIRECT_INSTANCING)
		// shadowMaskSelector.x is -1 if there is no shadow mask
		// Note that we override shadow value (in case we don't have any dynamic shadow)
		shadow = shadowMask = (light.shadowMaskSelector.x >= 0.0) ? dot(inputData.shadowMask, light.shadowMaskSelector) : 1.0;
	#endif

    #if !defined(_RECEIVE_SHADOWS_OFF) && (defined(SHADOWS_SOFT) || defined(SHADOWS_HARD))
        UNITY_BRANCH
        if (light.shadowIndex >= 0)
        {
            #if defined(SCREEN_SPACE_SHADOWS) && !defined(_TRANSPARENT_ON) && !defined(DISTORTION_ON)
                int screenSpaceMaskPacked = _ShadowDataBuffer[light.shadowIndex].screenSpaceMask;
                UNITY_BRANCH
                if (screenSpaceMaskPacked > -1)
                {
                    int textureIndex = screenSpaceMaskPacked >> 4;
                    float4 screenSpaceMask = float4((screenSpaceMaskPacked & (1 << 0)) > 0, (screenSpaceMaskPacked & (1 << 1)) > 0, (screenSpaceMaskPacked & (1 << 2)) > 0, (screenSpaceMaskPacked & (1 << 3)) > 0);
                    shadow = dot(LOAD_TEXTURE2D_ARRAY(_ScreenSpaceShadowmapRT, inputData.positionSS, textureIndex), screenSpaceMask);
                }
            #else
                shadow = EvalPunctualShadow(light.shadowIndex, light.direction, inputData.positionWS);
            #endif
        }
    #endif

    #if defined(SHADOWS_SHADOWMASK) && (defined(DEFERRED_ON) || defined(LIGHTMAP_ON)) || defined(INDIRECT_INSTANCING)
		// See comment in EvaluateBSDF_Punctual
		shadow = (light.shadowMaskSelector.x >= 0.0) ? min(shadowMask, shadow) : shadow;
		shadow = lerp(shadow, shadowMask, shadowFade);
	#else
		shadow = lerp(shadow, 1.0, shadowFade);
	#endif

    shadow = lerp(1, shadow, light.shadowStrength);

	light.attenuation *= shadow;

    EvalLighting(color, brdfData, inputData, light, false, materialFeatures);

    //color = inputData.linearDepth;
}

float4 FragmentPBR(InputData inputData, float3 albedo, float metallic, float3 specular,
    float smoothness, float occlusion, float3 emission, float alpha, float3 translucency, float wrapDiffuseFactor, uint materialFeatures)
{
	BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, translucency, wrapDiffuseFactor, brdfData);

	float3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);

    #ifdef DEBUG_DISPLAY
        if (_DebugLightingMode == DEBUGLIGHTINGMODE_SHADOWMASK
            || _DebugLightingMode == DEBUGLIGHTINGMODE_LIGHT_ATTENUATION
            || _DebugLightingMode == DEBUGLIGHTINGMODE_DIFFUSE
            || _DebugLightingMode == DEBUGLIGHTINGMODE_SPECULAR)
        {
            color = 0;
        }

		if (_DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTION_PROBES)
		{
			return float4(color, 1);
		}

        if (_DebugLightingMode == DEBUGLIGHTINGMODE_SPECULAR)
        {
            brdfData.diffuse = 0;
            emission = 0;
        }

        if (_DebugLightingMode == DEBUGLIGHTINGMODE_BAKED_GI)
        {
            return float4(inputData.bakedGI, 1);
        }

        if (_DebugMaterial == DEBUGMATERIAL_ALBEDO)
        {
            return float4(albedo.rgb, 1);
        }
        else if (_DebugMaterial == DEBUGMATERIAL_ROUGHNESS)
        {
            return float4(1 - smoothness.xxx, 1);
        }
        else if (_DebugMaterial == DEBUGMATERIAL_METALLIC)
        {
            return float4(metallic.xxx, 1);
        }
        else if (_DebugMaterial == DEBUGMATERIAL_EMISSION)
        {
            return float4(emission.rgb, 1);
        }
		else if (_DebugMaterial == DEBUGMATERIAL_TRANSLUCENCY)
		{
			return float4(translucency, 1);
		}
    #endif

	float shadowFade = saturate(inputData.linearDepth * _ShadowFadeDistanceScaleAndBias.x + _ShadowFadeDistanceScaleAndBias.y);

    // directional lights first
    for (int i = 0; i < _DirectionalLightsCount; i++)
    {
        int index = _LightIndicesBuffer[i];
        Light light = GetDirectionalLight(index);
        float shadow = 1.0;
		float shadowMask = 1.0;

		#if defined(SHADOWS_SHADOWMASK) && (defined(DEFERRED_ON) || defined(LIGHTMAP_ON)) || defined(INDIRECT_INSTANCING)
			// shadowMaskSelector.x is -1 if there is no shadow mask
			// Note that we override shadow value (in case we don't have any dynamic shadow)
			shadow = shadowMask = (light.shadowMaskSelector.x >= 0.0) ? dot(inputData.shadowMask, light.shadowMaskSelector) : 1.0;
		#endif

        #if !defined(_RECEIVE_SHADOWS_OFF) && (defined(SHADOWS_SOFT) || defined(SHADOWS_HARD))
            UNITY_BRANCH
            if (light.shadowIndex >= 0)
            {
                #if defined(SCREEN_SPACE_SHADOWS) && !defined(_TRANSPARENT_ON) && !defined(DISTORTION_ON)
                    int screenSpaceMaskPacked = _ShadowDataBuffer[light.shadowIndex].screenSpaceMask;
                    UNITY_BRANCH
                    if (screenSpaceMaskPacked > -1)
                    {
                        int textureIndex = screenSpaceMaskPacked >> 4;
                        float4 screenSpaceMask = float4((screenSpaceMaskPacked & (1 << 0)) > 0, (screenSpaceMaskPacked & (1 << 1)) > 0, (screenSpaceMaskPacked & (1 << 2)) > 0, (screenSpaceMaskPacked & (1 << 3)) > 0);
                        shadow = dot(LOAD_TEXTURE2D_ARRAY(_ScreenSpaceShadowmapRT, inputData.positionSS, textureIndex), screenSpaceMask);
                    }
                #else
                    shadow = EvalDirectionalShadow(light.shadowIndex, light.direction, inputData.positionWS);
                #endif
            }
        #endif

        #if defined(SHADOWS_SHADOWMASK) && (defined(DEFERRED_ON) || defined(LIGHTMAP_ON)) || defined(INDIRECT_INSTANCING)
			// See comment in EvaluateBSDF_Punctual
			shadow = (light.shadowMaskSelector.x >= 0.0) ? min(shadowMask, shadow) : shadow;
			shadow = lerp(shadow, shadowMask, shadowFade);
		#else
			shadow = lerp(shadow, 1.0, shadowFade);
		#endif

		shadow = lerp(1, shadow, light.shadowStrength);

		light.attenuation *= shadow;
        EvalLighting(color, brdfData, inputData, light, true, materialFeatures);
    }

	uint clusterIndex = GetClusterIndex(inputData.clusterUv);
	ClusterData cluster = _ClusterDataBuffer[clusterIndex];
	for (uint indexInCluster = 0; indexInCluster < cluster.count; indexInCluster++)
	{
		int lightIndex = _GlobalLightIndicesBuffer[cluster.offset + indexInCluster];
		Light light = GetPunctualLight(lightIndex, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);

		PunctualLighting(color, brdfData, inputData, light, shadowFade, materialFeatures);
	}

    #if defined(DEBUG_DISPLAY)
        if (_DebugLightingMode == DEBUGLIGHTINGMODE_EMISSION)
        {
            color = emission;
		}
        else if (_DebugLightingMode == DEBUGLIGHTINGMODE_NONE)
        {
            color += emission;
		}
    #else
        color += emission;
    #endif

    return float4(color, alpha);
}
#endif // OWLCAT_LIGHTING_INCLUDED
