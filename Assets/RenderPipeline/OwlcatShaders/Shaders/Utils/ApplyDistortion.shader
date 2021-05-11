Shader "Hidden/Owlcat/ApplyDistortion"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
            ZTest Always
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

            #pragma target 4.5

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "../../ShaderLibrary/Input.hlsl"
            #include "../../ShaderLibrary/Core.hlsl"
			#include "../../ShaderLibrary/DistortionUtils.hlsl"

			//#pragma multi_compile _ DISTORTION_FOREGROUND_FILTER

            struct Attributes
            {
                uint vertexID : VERTEXID_SEMANTIC;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);

                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
				// Get distortion values
				float4 encodedDistortion = LOAD_TEXTURE2D_X(_DistortionVectorsRT, input.positionCS.xy);

				float2 distortion;
				float distortionBlur;
				bool isDistortionSourceValid;
				DecodeDistortion(encodedDistortion, distortion, distortionBlur, isDistortionSourceValid);

				// Reject the pixel if it is not in the distortion mask
				if (!isDistortionSourceValid)
				{
					discard;
					return 0;
				}

				int2 distortedEncodedDistortionId = int2(input.positionCS.xy + distortion * _ScreenSize.xy);

				// Reject distortion if we try to fetch a pixel out of the buffer
				if (any(distortedEncodedDistortionId < 0)
					|| any(distortedEncodedDistortionId > int2(_ScreenSize.xy)))
				{
					// In this case we keep the blur, but we offset don't distort the uv coords.
					//distortion = -distortion;
				}

				// Get source pixel for distortion
				float2 distordedUV = float2(input.positionCS.xy * _ScreenSize.zw) + distortion;
				float mip = (_ColorPyramidLodCount - 1) * clamp(distortionBlur, 0.0, 1.0);
				float4 sampled = SAMPLE_TEXTURE2D_X_LOD(_CameraColorPyramidRT, s_trilinear_clamp_sampler, distordedUV, mip);
				return sampled;
            }

			ENDHLSL
		}
	}
}
