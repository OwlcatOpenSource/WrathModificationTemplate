Shader "Hidden/Owlcat/Fog"
{
    SubShader
    {
        Tags{ "RenderPipeline" = "OwlcatPipeline" }

        Pass
        {
            ZWrite Off
			ZTest Always
			Cull Off
			Blend OneMinusSrcAlpha SrcAlpha

            HLSLPROGRAM
				#pragma target 4.5
				#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

				#define POST_PROCESS_FOG

				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
				#include "../../ShaderLibrary/Input.hlsl"
				#include "../../ShaderLibrary/Core.hlsl"

				#pragma multi_compile _ DEFERRED_ON
				#pragma multi_compile_fog

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
					float deviceDepth = LOAD_TEXTURE2D(_CameraDepthRT, input.positionCS.xy).x;

					if (deviceDepth == UNITY_RAW_FAR_CLIP_VALUE)
					{
						return 1;
					}

					float linearDepth = LinearEyeDepth(deviceDepth);
					float fogFactor = ComputeFogFactor(linearDepth);
					float lerpFactor = FogLerpFactor(fogFactor);
					return float4(LinearToSRGB(unity_FogColor.rgb), lerpFactor);
				}
            ENDHLSL
        }
    }

    Fallback Off
}
