Shader "Hidden/Owlcat/FinalBlit"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "OwlcatPipeline"}
        LOD 100

        Pass
        {
            Name "Blit"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma multi_compile _ _LINEAR_TO_SRGB_CONVERSION
            #pragma multi_compile _ _KILL_ALPHA

            #include "../../ShaderLibrary/Core.hlsl"
            #ifdef _LINEAR_TO_SRGB_CONVERSION
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #endif

            #define NAN_COLOR half3(0.0, 0.0, 0.0)

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS    : SV_POSITION;
                float2 uv            : TEXCOORD0;
            };

            TEXTURE2D(_BlitTex);
            SAMPLER(sampler_BlitTex);

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float4 Fragment(Varyings input) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_BlitTex, sampler_BlitTex, input.uv);
				#if !defined(UNITY_COLORSPACE_GAMMA) && !defined(_LINEAR_TO_SRGB_CONVERSION)
					col.rgb = SRGBToLinear(col.rgb);
				#endif
                //#ifdef _LINEAR_TO_SRGB_CONVERSION
				//	col = LinearToSRGB(col);
                //#endif
                #ifdef _KILL_ALPHA
					col.a = 1.0;
                #endif

                if (AnyIsNaN(col.rgb) || AnyIsInf(col.rgb))
                    col.rgb = NAN_COLOR;

                return col;
            }
            ENDHLSL
        }
    }
}
