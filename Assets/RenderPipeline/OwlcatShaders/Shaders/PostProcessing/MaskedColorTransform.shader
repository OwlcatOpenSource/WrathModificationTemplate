Shader "Hidden/Owlcat/Render Pipeline/MaskedColorTransform"
{
	Properties
	{
		//_MainTex ("Texture", 2D) = "white" {}
		//_Color("", Color) = (1,1,1,1)
		//_StencilRef("Stencil Ref", float) = 0
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Stencil
		{
			Ref [_StencilRef] // see StencilRef
			ReadMask [_StencilRef]
			Comp equal
		}

		Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			
			#include "../../ShaderLibrary/Core.hlsl"

			struct Attributes
			{
				uint vertexID : SV_VertexID;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float2 texcoord   : TEXCOORD0;
			};
						
			TEXTURE2D(_BlitTexture);
			SamplerState sampler_PointClamp;
			half4 _MaskedColorTransformParams;

			Varyings Vert(Attributes input)
			{
				Varyings output;
				output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
				output.texcoord   = GetFullScreenTriangleTexCoord(input.vertexID);
				return output;
			}

			half ColorOverlay(half base, half blend)
			{
				return base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
			}

			half4 Frag (Varyings input) : SV_Target
			{
				half4 color = SAMPLE_TEXTURE2D_LOD(_BlitTexture, sampler_PointClamp, input.texcoord.xy, 0);

				#if !defined(UNITY_COLORSPACE_GAMMA)
					//color.rgb = SRGBToLinear(color.rgb);
				#endif

				// REF: https://timseverien.com/posts/2020-06-19-colour-correction-with-webgl/

				// brightness
				color.rgb += _MaskedColorTransformParams.x;

				// contrast
				color.rgb = 0.5 + _MaskedColorTransformParams.y * (color.rgb - 0.5);

				#if !defined(UNITY_COLORSPACE_GAMMA)
					//color.rgb = LinearToSRGB(color.rgb);
				#endif

				return color;
			}
			ENDHLSL
		}
	}
}
