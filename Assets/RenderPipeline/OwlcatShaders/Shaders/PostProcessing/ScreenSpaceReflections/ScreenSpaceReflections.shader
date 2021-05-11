Shader "Hidden/Owlcat/ScreenSpaceReflections"
{
    HLSLINCLUDE
        #pragma target 4.5

		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "../../../ShaderLibrary/Input.hlsl"
        #include "../../../ShaderLibrary/Core.hlsl"
        #include "../../../ShaderLibrary/Lighting.hlsl"
        #include "../../../Lighting/DeferredData.cs.hlsl"

        #pragma multi_compile _ HBAO_ON

        struct Attributes
        {
            uint vertexID : VERTEXID_SEMANTIC;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD0;
            float3 cameraRay : TEXCOORD1;
        };

        Varyings Vert(Attributes input)
        {
            Varyings output;
            output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
            output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);

            output.cameraRay = CreateRay(output.positionCS.xy);

            return output;
        }

        #define SPEC_POWER 16
        #define CNST_MAX_SPECULAR_EXP 2^SPEC_POWER

        CBUFFER_START(UnityScreenSpaceReflections)
            int _SsrMinDepthMipLevel;
            float _SsrRoughnessFadeEnd;
            float _SsrRoughnessFadeStart;
            float _SsrFresnelPower;
            float _SsrConfidenceScale;
            float _HbaoIntensity;
        CBUFFER_END
        
        TEXTURE2D(_HBAOTex);

        float SmoothnessToSpecularPower(float smoothness)
        {
            return exp2(SPEC_POWER * smoothness + 1);
        }

        float SpecularPowerToConeAngle(float specularPower)
        {
            // based on phong distribution model
            if(specularPower >= exp2(CNST_MAX_SPECULAR_EXP))
            {
                return 0.0f;
            }
            const float xi = 0.244f;
            float exponent = 1.0f / (specularPower + 1.0f);
            return acos(pow(xi, exponent));
        }

        float IsoscelesTriangleOpposite(float adjacentLength, float coneTheta)
        {
            // simple trig and algebra - soh, cah, toa - tan(theta) = opp/adj, opp = tan(theta) * adj, then multiply * 2.0f for isosceles triangle base
            return 2.0f * tan(coneTheta) * adjacentLength;
        }

        float IsoscelesTriangleInRadius(float a, float h)
        {
            float a2 = a * a;
            float fh2 = 4.0f * h * h;
            return (a * (sqrt(a2 + fh2) - a)) / (4.0f * h);
        }

        float4 ConeSampleWeightedColor(float2 samplePos, float mipChannel, float gloss)
        {
            float3 sampleColor = SAMPLE_TEXTURE2D_LOD(_CameraColorPyramidRT, s_trilinear_clamp_sampler, samplePos, mipChannel).rgb;
            return float4(sampleColor * gloss, gloss);
        }

        float IsoscelesTriangleNextAdjacent(float adjacentLength, float incircleRadius)
        {
            // subtract the diameter of the incircle to get the adjacent side of the next level on the cone
            return adjacentLength - (incircleRadius * 2.0f);
        }

        float3 ResolveSsr(float2 hit, float2 screenUv, float smoothness)
        {
            float specularPower = SmoothnessToSpecularPower(smoothness);

            // convert to cone angle (maximum extent of the specular lobe aperture)
            // only want half the full cone angle since we're slicing the isosceles triangle in half to get a right triangle
            float coneTheta = SpecularPowerToConeAngle(specularPower) * 0.5f;

            // P1 = positionSS, P2 = raySS, adjacent length = ||P2 - P1||
            float2 deltaP = hit.xy - screenUv.xy;
            float adjacentLength = length(deltaP);
            float2 adjacentUnit = normalize(deltaP);

            float maxMipLevel = (float)_ColorPyramidLodCount - 1.0f;

            // intersection length is the adjacent side, get the opposite side using trig
            float oppositeLength = IsoscelesTriangleOpposite(adjacentLength, coneTheta);

            // calculate in-radius of the isosceles triangle
            float incircleSize = IsoscelesTriangleInRadius(oppositeLength, adjacentLength);

            // convert the in-radius into screen size then check what power N to raise 2 to reach it - that power N becomes mip level to sample from
            float mipChannel = clamp(log2(incircleSize * max(_ScreenSize.x, _ScreenSize.y)), 0.0f, maxMipLevel);

            return SAMPLE_TEXTURE2D_LOD(_CameraColorPyramidRT, s_trilinear_clamp_sampler, hit.xy, mipChannel).rgb;
        }

        float CalculateFade(float2 hit, float smoothness)
        {
            // edge fade
            // идея простая, hit.xy - это координаты выборки из текстуры, чем ближе к краю эти координаты, тем сильнее фейдим
            float2 edgeFade = abs(hit.xy * 2 - 1);
            edgeFade.x = Pow4(edgeFade.x);
            edgeFade.y = Pow4(edgeFade.y);
            edgeFade = saturate(1 - edgeFade);

            float fade = min(edgeFade.x, edgeFade.y);
            fade *= 2 * fade; // 2 and 1.5 are quite important for the correct ratio of 3:2 distribution
                
            fade = saturate(1.5 * fade * smoothstep(0.5, 1.0, 1.5 * fade));

            // roughness fade
            float roughness = 1.0 - smoothness;

            fade *= roughness < _SsrRoughnessFadeStart ? 1 : 1 - (roughness - _SsrRoughnessFadeStart) / (_SsrRoughnessFadeEnd - _SsrRoughnessFadeStart);

            return fade;
        }

        float FetchHbao(float2 uv)
        {
            #ifdef HBAO_ON
                float hbao = SAMPLE_TEXTURE2D_LOD(_HBAOTex, s_linear_clamp_sampler, uv.xy, 0).a;
                hbao = saturate(pow(hbao, _HbaoIntensity));
                return hbao;
            #else
                return 1;
            #endif
        }
    ENDHLSL

    SubShader
    {
        Pass
		{
            Name "Resolve and composite"

            ZTest Always
            Cull Off

			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

            TEXTURE2D(_SsrHitPointTexture);
            float4 _SsrHitPointTexture_TexelSize;

            float4 Frag(Varyings input) : SV_Target
            {
                float4 color = LOAD_TEXTURE2D(_CameraColorPyramidRT, input.positionCS.xy);

                float2 scale = 1 << _SsrMinDepthMipLevel;
                uint2 scaledPositionCS = uint2(input.positionCS.xy / scale);
                float2 hit = LOAD_TEXTURE2D_LOD(_SsrHitPointTexture, scaledPositionCS, 0).xy;

                //return float4(hit, 0, 1);
                if (length(hit) <= 0)
                {
                    return color;
                }

                float4 translusencyAndMaterialFeatures = LOAD_TEXTURE2D(_CameraTranslucencyRT, input.positionCS.xy);
			    uint materialFeatures = UnpackByte(translusencyAndMaterialFeatures.a);
			    if (!HasFlag(materialFeatures, MATERIALFEATURES_REFLECTIONS))
			    {
				    return color;
			    }

                float4 normalAndSmoothness = DecodeNormalAndSmoothness(LOAD_TEXTURE2D(_CameraNormalsRT, input.positionCS.xy));

                //---------------------------------
                // RESOLVE SSR
                //---------------------------------
                float3 ssr = ResolveSsr(hit, input.texcoord.xy, normalAndSmoothness.a);

                // из-за костыля ПФ1 приходится переводить в Linear и обратно
                #if !defined(UNITY_COLORSPACE_GAMMA)
                    color.rgb = SRGBToLinear(color.rgb);
                    ssr.rgb = SRGBToLinear(ssr.rgb);
                #endif

                float deviceDepth = LOAD_TEXTURE2D(_CameraDepthRT, input.positionCS.xy).x;
                float3 positionWS = ReconstructPositionFromDeviceDepth(input.cameraRay, _WorldSpaceCameraPos, deviceDepth);
                float3 viewDirectionWS = normalize(_WorldSpaceCameraPos.xyz - positionWS.xyz);

                //---------------------------------
                // CONFIDENCE
                //---------------------------------
                float fade = CalculateFade(hit, normalAndSmoothness.a);

                //return confidence.x;

                //if (_SsrMinDepthMipLevel > 0)
                //{
                //    float2 origPositioinCS = uint2(scaledPositionCS.xy * scale).xy;//float4(input.positionCS.xy - uint2(scaledPositionCS.xy * scale).xy, 0, 1);
                //    float4 normalAndSmoothnessOrig = DecodeNormalAndSmoothness(LOAD_TEXTURE2D(_CameraNormalsRT, origPositioinCS.xy));
                //    confidence *= Pow4(Pow4(dot(normalAndSmoothness.xyz, normalAndSmoothnessOrig.xyz)));
                //}


                //---------------------------------
                // MIX WITH DEFERRED GBUFFER
                //---------------------------------
                float3 cubemaps = LOAD_TEXTURE2D(_CameraDeferredReflectionsRT, input.positionCS.xy).rgb;

                BRDFData brdfData;
                float4 albedoAndMetallic = LOAD_TEXTURE2D(_CameraAlbedoRT, input.positionCS.xy);
                InitializeBRDFData(
                    albedoAndMetallic.rgb,                  // albedo
                    albedoAndMetallic.a,                    // metallic
                    0,                                      // specular
                    normalAndSmoothness.a,                  // smoothness
                    1,                                      // alpha
                    translusencyAndMaterialFeatures.rgb,    // translucency
                    0,                                      // wrapDiffuseFactor
                    brdfData);

                float fresnelTerm = saturate(pow(1.0 - saturate(dot(normalAndSmoothness.xyz, viewDirectionWS.xyz)), _SsrFresnelPower) * _SsrConfidenceScale);

                float3 envBrdf = EnvironmentBRDF(
                    brdfData,
                    0, // indirectDiffuse
                    ssr, // indirectSpecular
                    fresnelTerm);

                #ifdef HBAO_ON
                    float hbao = FetchHbao(input.texcoord.xy);
                    cubemaps *= hbao;
                    envBrdf *= hbao;
                #endif

                envBrdf = lerp(cubemaps, envBrdf, fade);

                float3 finalColor = color.rgb - cubemaps;
                finalColor.rgb = max(0.0, finalColor.rgb + envBrdf.rgb);

                #if !defined(UNITY_COLORSPACE_GAMMA)
                    finalColor.rgb = LinearToSRGB(finalColor.rgb);
                #endif

                return float4(finalColor.rgb, 1);
            }

			ENDHLSL
		}

        Pass
		{
            Name "Resolve"

            ZTest Always
            Cull Off

			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

            TEXTURE2D(_SsrHitPointTexture);

            float4 Frag(Varyings input) : SV_Target
            {
                float2 hit = LOAD_TEXTURE2D_LOD(_SsrHitPointTexture, input.positionCS.xy, 0).xy;
                //return float4(hit, 0, 1);
                if (length(hit) <= 0)
                {
                    return 0;
                }

                float4 translusencyAndMaterialFeatures = SAMPLE_TEXTURE2D(_CameraTranslucencyRT, s_point_clamp_sampler, input.texcoord.xy);
			    uint materialFeatures = UnpackByte(translusencyAndMaterialFeatures.a);
			    if (!HasFlag(materialFeatures, MATERIALFEATURES_REFLECTIONS))
			    {
				    return 0;
			    }

                float4 normalAndSmoothness = DecodeNormalAndSmoothness(SAMPLE_TEXTURE2D(_CameraNormalsRT, s_point_clamp_sampler, input.texcoord.xy));

                //---------------------------------
                // RESOLVE SSR
                //---------------------------------
                float3 ssr = ResolveSsr(hit, input.texcoord.xy, normalAndSmoothness.a);

                // из-за костыля ПФ1 приходится переводить в Linear и обратно
                #if !defined(UNITY_COLORSPACE_GAMMA)
                    ssr.rgb = SRGBToLinear(ssr.rgb);
                #endif

                //---------------------------------
                // CONFIDENCE
                //---------------------------------
                float deviceDepth = SAMPLE_TEXTURE2D(_CameraDepthRT, s_point_clamp_sampler, input.texcoord.xy).x;
                float3 positionWS = ReconstructPositionFromDeviceDepth(input.cameraRay, _WorldSpaceCameraPos, deviceDepth);
                float3 viewDirectionWS = normalize(_WorldSpaceCameraPos.xyz - positionWS.xyz);

                float fade = CalculateFade(hit, normalAndSmoothness.a);

                return float4(ssr.rgb, fade);
            }

			ENDHLSL
		}

        Pass
		{
            Name "Upsample and composite"

            ZTest Always
            Cull Off

			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

            TEXTURE2D(_SsrResolveTexture);

            float4 Frag(Varyings input) : SV_Target
            {
                float4 color = LOAD_TEXTURE2D(_CameraColorPyramidRT, input.positionCS.xy);

                // Upsample via billinear filtering
                float4 ssr = SAMPLE_TEXTURE2D(_SsrResolveTexture, s_linear_clamp_sampler, input.texcoord.xy);
                //return ssr.a;

                #define fade ssr.a

                if (fade <= 0)
                {
                    return color;
                }

                //---------------------------------
                // MIX WITH DEFERRED GBUFFER
                //---------------------------------
                float deviceDepth = LOAD_TEXTURE2D(_CameraDepthRT, input.positionCS.xy).x;
                float3 positionWS = ReconstructPositionFromDeviceDepth(input.cameraRay, _WorldSpaceCameraPos, deviceDepth);
                float3 cubemaps = LOAD_TEXTURE2D(_CameraDeferredReflectionsRT, input.positionCS.xy).rgb;
                
                // из-за костыля ПФ1 приходится переводить в Linear и обратно
                #if !defined(UNITY_COLORSPACE_GAMMA)
                    color.rgb = SRGBToLinear(color.rgb);
                #endif

                BRDFData brdfData;
                float4 albedoAndMetallic = LOAD_TEXTURE2D(_CameraAlbedoRT, input.positionCS.xy);
                float4 normalAndSmoothness = DecodeNormalAndSmoothness(LOAD_TEXTURE2D(_CameraNormalsRT, input.positionCS.xy));
                float4 translusencyAndMaterialFeatures = LOAD_TEXTURE2D(_CameraTranslucencyRT, input.positionCS.xy);

                InitializeBRDFData(
                    albedoAndMetallic.rgb,                  // albedo
                    albedoAndMetallic.a,                    // metallic
                    0,                                      // specular
                    normalAndSmoothness.a,                  // smoothness
                    1,                                      // alpha
                    translusencyAndMaterialFeatures.rgb,    // translucency
                    0,                                      // wrapDiffuseFactor
                    brdfData);

                float3 viewDirectionWS = normalize(_WorldSpaceCameraPos.xyz - positionWS.xyz);
                float fresnelTerm = saturate(pow(1.0 - saturate(dot(normalAndSmoothness.xyz, viewDirectionWS.xyz)), _SsrFresnelPower) * _SsrConfidenceScale);

                //float3 envBrdf = ssr;
                float3 envBrdf = EnvironmentBRDF(
                    brdfData,
                    0, // indirectDiffuse
                    ssr.rgb, // indirectSpecular
                    fresnelTerm);

                #ifdef HBAO_ON
                    float hbao = FetchHbao(input.texcoord.xy);
                    cubemaps *= hbao;
                    envBrdf *= hbao;
                #endif

                envBrdf = lerp(cubemaps, envBrdf.rgb, fade);

                float3 finalColor = color.rgb - cubemaps;
                finalColor.rgb = max(0.0, finalColor.rgb + envBrdf.rgb);

                #if !defined(UNITY_COLORSPACE_GAMMA)
                    finalColor.rgb = LinearToSRGB(finalColor.rgb);
                #endif

                return float4(finalColor.rgb, 1);
            }

			ENDHLSL
		}
    }
}
