Shader "Hidden/Owlcat/ScreenSpaceCloudShadows"
{
    SubShader
    {
        Tags{ "RenderPipeline" = "OwlcatPipeline" }

        Pass
        {
            ZWrite Off
			ZTest Always
			Cull Off
			ColorMask RGB
			Blend DstColor Zero
			//Blend One One

            HLSLPROGRAM
				#pragma target 4.5
				#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
				#include "../../ShaderLibrary/Input.hlsl"
				#include "../../ShaderLibrary/Core.hlsl"

                #pragma vertex Vert
                #pragma fragment Frag

				struct Attributes
				{
					uint vertexID : VERTEXID_SEMANTIC;
				};

				struct Varyings
				{
					float4 positionCS	: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
				};

				TEXTURE2D(_Texture0);
				TEXTURE2D(_Texture1);

				CBUFFER_START(ScreenSpaceCloudShadows)
					float4 _Texture0ScaleBias;
					float4 _Texture1ScaleBias;
					float4 _Texture0Color;
					float4 _Texture1Color;
					float _Intensity;
				CBUFFER_END

				Varyings Vert(Attributes input)
				{
					Varyings output;
					output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
					output.texcoord   = GetFullScreenTriangleTexCoord(input.vertexID);

					#if UNITY_UV_STARTS_AT_TOP
						if (_ProjectionParams.x > 0)
							output.texcoord.y = 1 - output.texcoord.y;
					#endif

					return output;
				}

				float4 Frag(Varyings input) : SV_Target
				{
					DepthGradients depthGradients = GetDepthGradients(input.positionCS.xy);
					float4 bakedGI = LOAD_TEXTURE2D(_CameraBakedGIRT, input.positionCS.xy);

					float3 positionWS = ComputeWorldSpacePosition(input.positionCS.xy * _ScreenSize.zw + _ScreenSize.zw * .5, depthGradients.Depth, UNITY_MATRIX_I_VP);
					float3 positionDX = ComputeWorldSpacePosition(depthGradients.Dx.xy * _ScreenSize.zw, depthGradients.Dx.z, UNITY_MATRIX_I_VP);
					float3 positionDY = ComputeWorldSpacePosition(depthGradients.Dy.xy * _ScreenSize.zw, depthGradients.Dy.z, UNITY_MATRIX_I_VP);

					float4 textureGradients = float4(positionWS.xz - positionDX.xz, positionWS.xz - positionDY.xz);

					float2 scale0 = _Texture0ScaleBias.xy * 0.005; // 0.005 is some magic value
					float2 uv0 = positionWS.xz * scale0 + _Texture0ScaleBias.zw;
					float4 sample0 = SAMPLE_TEXTURE2D_GRAD(_Texture0, s_linear_repeat_sampler, uv0, textureGradients.xy * scale0, textureGradients.zw * scale0);
					float lum = dot(sample0.rgb, float3(0.3, 0.59, 0.11));
					sample0.rgb = lerp(float3(1,1,1), bakedGI.rgb * _Texture0Color.rgb, lum * _Texture0Color.a * _Intensity);

					float2 scale1 = _Texture1ScaleBias.xy * 0.005; // 0.005 is some magic value
					float2 uv1 = positionWS.xz * scale1 + _Texture1ScaleBias.zw;
					float4 sample1 = SAMPLE_TEXTURE2D_GRAD(_Texture1, s_linear_repeat_sampler, uv1, textureGradients.xy * scale1, textureGradients.zw * scale1);
					lum = dot(sample1.rgb, float3(0.3, 0.59, 0.11));
					sample1.rgb = lerp(float3(1,1,1), bakedGI.rgb * _Texture1Color.rgb, lum * _Texture1Color.a * _Intensity);

					return sample0 * sample1;
				}
            ENDHLSL
        }
    }

    Fallback Off
}
