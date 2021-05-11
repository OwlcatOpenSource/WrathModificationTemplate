Shader "Hidden/Owlcat Render Pipeline/BloomEnhanced"
{
    Properties
    {
        _MainTex("Source", 2D) = "white" {}
    }

    HLSLINCLUDE

        #pragma multi_compile_local _ _USE_RGBM

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
        #include "../../ShaderLibrary/Core.hlsl"
        #include "Common.hlsl"

        TEXTURE2D_X(_MainTex);
		TEXTURE2D_X(_BaseTex);

        float4 _MainTex_TexelSize;

        float4 _Params; // x: threshold (linear), y: prefilterOffs, z: sampleScale, w: dirtIntensity
        float4 _Params1; // x: clamp
		float4 _Curve;

        #define Threshold			_Params.x
        #define PrefilterOffs		_Params.y
        #define SampleScale			_Params.z
        #define DirtIntensity		_Params.w

        half4 EncodeHDR(half3 color)
        {
        #if _USE_RGBM
            half4 outColor = EncodeRGBM(color);
        #else
            half4 outColor = half4(color, 1.0);
        #endif

        #if UNITY_COLORSPACE_GAMMA
            return half4(sqrt(outColor.xyz), outColor.w); // linear to γ
        #else
            return outColor;
        #endif
        }

        half3 DecodeHDR(half4 color)
        {
        #if UNITY_COLORSPACE_GAMMA
            color.xyz *= color.xyz; // γ to linear
        #endif

        #if _USE_RGBM
            return DecodeRGBM(color);
        #else
            return color.xyz;
        #endif
        }

		// Brightness function
		half Brightness(half3 c)
		{
			return max(max(c.r, c.g), c.b);
		}

		// 3-tap median filter
		half3 Median(half3 a, half3 b, half3 c)
		{
			return a + b + c - min(min(a, b), c) - max(max(a, b), c);
		}

		// Downsample with a 4x4 box filter
		half3 DownsampleFilter(TEXTURE2D_PARAM(textureName, samplerName), float2 uv, float2 texelSize)
		{
			float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

			half3 s;
			s = DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xy));
			s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zy));
			s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xw));
			s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zw));

			return s * (1.0 / 4.0);
		}

		// Downsample with a 4x4 box filter + anti-flicker filter
		half3 DownsampleAntiFlickerFilter(TEXTURE2D_PARAM(textureName, samplerName), float2 uv, float2 texelSize)
		{
			float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

			half3 s1 = DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xy));
			half3 s2 = DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zy));
			half3 s3 = DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xw));
			half3 s4 = DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zw));

			// Karis's luma weighted average (using brightness instead of luma)
			half s1w = 1.0 / (Brightness(s1) + 1.0);
			half s2w = 1.0 / (Brightness(s2) + 1.0);
			half s3w = 1.0 / (Brightness(s3) + 1.0);
			half s4w = 1.0 / (Brightness(s4) + 1.0);
			half one_div_wsum = 1.0 / (s1w + s2w + s3w + s4w);

			return (s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) * one_div_wsum;
		}

		half3 UpsampleFilter(TEXTURE2D_PARAM(textureName, samplerName), float2 uv, float2 texelSize, float sampleScale)
		{
			#if MOBILE_OR_CONSOLE
				// 4-tap bilinear upsampler
				float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0) * (sampleScale * 0.5);

				half3 s;
				s =  DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xy));
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zy));
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xw));
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zw));

				return s * (1.0 / 4.0);
			#else
				// 9-tap bilinear upsampler (tent filter)
				float4 d = texelSize.xyxy * float4(1.0, 1.0, -1.0, 0.0) * sampleScale;

				half3 s;
				s =  DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv - d.xy));
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv - d.wy)) * 2.0;
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv - d.zy));

				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zw)) * 2.0;
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv))        * 4.0;
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xw)) * 2.0;

				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.zy));
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.wy)) * 2.0;
				s += DecodeHDR(SAMPLE_TEXTURE2D_X(textureName, samplerName, uv + d.xy));

				return s * (1.0 / 16.0);
			#endif
		}

        half4 FragPrefilter(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
			float2 uv = input.uv + _MainTex_TexelSize.xy * PrefilterOffs;
            half3 color = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv).xyz;

		   #if ANTI_FLICKER
				float3 d = _MainTex_TexelSize.xyx * float3(1.0, 1.0, 0.0);
				half4 s0 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv);
				half3 s1 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv - d.xz).rgb;
				half3 s2 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv + d.xz).rgb;
				half3 s3 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv - d.zy).rgb;
				half3 s4 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv + d.zy).rgb;
				half3 m = Median(Median(s0.rgb, s1, s2), s3, s4);
			#else
				half4 s0 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv);
				half3 m = s0.rgb;
			#endif

			#if UNITY_COLORSPACE_GAMMA
				m = SRGBToLinear(m);
			#endif

            // User controlled clamp to limit crazy high broken spec
            m = min(_Params1.x, m);

            // Pixel brightness
            half br = Brightness(m);

            // Under-threshold part: quadratic curve
            half rq = clamp(br - _Curve.x, 0.0, _Curve.y);
            rq = _Curve.z * rq * rq;

            // Combine and apply the brightness response curve.
            m *= max(rq, br - Threshold) / max(br, 1e-5);

            return EncodeHDR(m);
        }

        half4 FragDownsample1(Varyings i) : SV_Target
        {
			#if ANTI_FLICKER
				return EncodeHDR(DownsampleAntiFlickerFilter(TEXTURE2D_ARGS(_MainTex, sampler_LinearClamp), i.uv, _MainTex_TexelSize.xy));
			#else
				return EncodeHDR(DownsampleFilter(TEXTURE2D_ARGS(_MainTex, sampler_LinearClamp), i.uv, _MainTex_TexelSize.xy));
			#endif
        }

        half4 FragDownsample2(Varyings i) : SV_Target
        {
            return EncodeHDR(DownsampleFilter(TEXTURE2D_ARGS(_MainTex, sampler_LinearClamp), i.uv, _MainTex_TexelSize.xy));
        }

        half4 FragUpsample(Varyings i) : SV_Target
        {
            half3 base = DecodeHDR(SAMPLE_TEXTURE2D_X(_BaseTex, sampler_LinearClamp, i.uv));
            half3 blur = UpsampleFilter(TEXTURE2D_ARGS(_MainTex, sampler_LinearClamp), i.uv, _MainTex_TexelSize.xy, SampleScale);
            return EncodeHDR(base + blur);
        }

    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "Bloom Prefilter"

            HLSLPROGRAM
				#pragma multi_compile __ ANTI_FLICKER

                #pragma vertex Vert
                #pragma fragment FragPrefilter
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blur Horizontal"

            HLSLPROGRAM
                #pragma vertex Vert
				#pragma fragment FragDownsample1
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blur Vertical"

            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment FragDownsample2
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Upsample"

            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment FragUpsample
            ENDHLSL
        }
    }
}
