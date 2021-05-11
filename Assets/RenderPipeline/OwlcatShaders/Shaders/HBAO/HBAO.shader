// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/Owlcat/HBAO"
{
	Properties {
		_MainTex ("", 2D) = "" {}
		_HBAOTex ("", 2D) = "" {}
		_NoiseTex("", 2D) = "" {}
		_DepthTex("", 2D) = "" {}
		_NormalsTex("", 2D) = "" {}
		_rt0Tex("", 2D) = "" {}
		_rt3Tex("", 2D) = "" {}
	}

	CGINCLUDE
		#pragma target 3.0
		#pragma multi_compile __ DEFERRED_SHADING_ON ORTHOGRAPHIC_PROJECTION_ON
		#pragma multi_compile __ COLOR_BLEEDING_ON
		#pragma multi_compile __ NORMALS_CAMERA NORMALS_RECONSTRUCT
		#pragma multi_compile __ OFFSCREEN_SAMPLES_CONTRIB

		#include "UnityCG.cginc"

		#if !defined(UNITY_UNROLL)
		#if defined(UNITY_COMPILER_HLSL)
		#define UNITY_UNROLL	[unroll]
		#else
		#define UNITY_UNROLL
		#endif
		#endif

		sampler2D _MainTex;
		sampler2D _HBAOTex;
		sampler2D _rt0Tex;
		sampler2D _rt3Tex;
		float4 _MainTex_TexelSize;

		sampler2D_float _CameraDepthTexture;
		sampler2D_float _CameraDepthNormalsTexture;
		sampler2D_float _CameraGBufferTexture0; // diffuse color (RGB), occlusion (A)
		sampler2D_float _CameraGBufferTexture2; // normal (rgb), --unused-- (a)
		sampler2D_float _NoiseTex;
		sampler2D_float _DepthTex;
		sampler2D_float _NormalsTex;

		float4 _CameraDepthTexture_ST;
		float4 _MainTex_ST;

		CBUFFER_START(FrequentlyUpdatedUniforms)
		float4 _UVToView;
		float4x4 _WorldToCameraMatrix;
		float _Radius;
		float _MaxRadiusPixels;
		float _NegInvRadius2;
		float _AngleBias;
		float _AOmultiplier;
		float _Intensity;
		half4 _BaseColor;
		float _NoiseTexSize;
		float _BlurSharpness;
		float _ColorBleedSaturation;
		float _AlbedoMultiplier;
		float _ColorBleedBrightnessMask;
		float2 _ColorBleedBrightnessMaskRange;
		float _MultiBounceInfluence;
		float _OffscreenSamplesContrib;
		float _MaxDistance;
		float _DistanceFalloff;
		float4 _TargetScale;
		CBUFFER_END

		CBUFFER_START(FrequentlyUpdatedDeinterleavingUniforms)
		float4 _FullRes_TexelSize;
		float4 _LayerRes_TexelSize;
		CBUFFER_END

		CBUFFER_START(PerPassUpdatedDeinterleavingUniforms)
		float2 _Deinterleaving_Offset00;
		float2 _Deinterleaving_Offset10;
		float2 _Deinterleaving_Offset01;
		float2 _Deinterleaving_Offset11;
		float2 _LayerOffset;
		float4 _Jitter;
		CBUFFER_END

		struct DeinterleavedOutput {
			float4 Z00 : SV_Target0;
			float4 Z10 : SV_Target1;
			float4 Z01 : SV_Target2;
			float4 Z11 : SV_Target3;
		};

		struct v2f {
			float2 uv : TEXCOORD0;
			float2 uv2 : TEXCOORD1;
		};

		v2f vert(appdata_img v, out float4 outpos : SV_POSITION) {
			v2f o;
			o.uv = v.texcoord.xy;
			o.uv2 = v.texcoord.xy;
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv2.y = 1 - o.uv2.y;
			#endif
			outpos = UnityObjectToClipPos(v.vertex);
			return o;
		}

		v2f vert_mesh(appdata_img v, out float4 outpos : SV_POSITION) {
			v2f o;
			o.uv = v.texcoord;
			o.uv2 = v.texcoord;
			if (_ProjectionParams.x < 0)
				o.uv2.y = 1 - o.uv2.y;
			outpos = v.vertex * float4(2, 2, 0, 0) + float4(0, 0, 0, 1);
			#ifdef UNITY_HALF_TEXEL_OFFSET
			outpos.xy += (1.0 / _ScreenParams.xy) * float2(-1, 1);
			#endif
			return o;
		}

		v2f vert_atlas(appdata_img v, out float4 outpos : SV_POSITION) {
			v2f o;
			o.uv = v.texcoord.xy;
			o.uv2 = v.texcoord.xy;
			#ifdef UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv2.y = 1 - o.uv2.y;
			#endif
			outpos = UnityObjectToClipPos(float4(v.vertex.xy * (_LayerRes_TexelSize.zw / _FullRes_TexelSize.zw) + _LayerOffset * _FullRes_TexelSize.xy, v.vertex.zw));
			return o;
		}

		inline half4 FetchOcclusion(float2 uv) {
			#if UNITY_SINGLE_PASS_STEREO
			half4 occ = tex2D(_HBAOTex, UnityStereoTransformScreenSpaceTex(uv) * _TargetScale.zw);
			#else
			half4 occ = tex2D(_HBAOTex, uv * _TargetScale.zw);
			#endif
			occ.a = saturate(pow(occ.a, _Intensity));
			return occ;
		}

		inline half4 FetchSceneColor(float2 uv) {
			#if UNITY_SINGLE_PASS_STEREO
			half4 col = tex2D(_MainTex, UnityStereoTransformScreenSpaceTex(uv));
			#else
			half4 col = tex2D(_MainTex, uv);
			#endif
			return col;
		}

		inline half3 MultiBounceAO(float visibility, half3 albedo) {
			half3 a = 2.0404 * albedo - 0.3324;
			half3 b = -4.7951 * albedo + 0.6417;
			half3 c = 2.7552 * albedo + 0.6903;

			float x = visibility;
			return max(x, ((x * a + b) * x + c) * x);
		}

		// Unpack 2 float of 12bit packed into a 888
		float2 Unpack888ToFloat2(float3 x)
		{
			uint3 i = (uint3)(x * 255.0);
			// 8 bit in lo, 4 bit in hi
			uint hi = i.z >> 4;
			uint lo = i.z & 15;
			uint2 cb = i.xy | uint2(lo << 8, hi << 8);

			return cb / 4095.0;
		}

		float3 UnpackNormalOctQuadEncode(float2 f)
		{
			float3 n = float3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));

			//float2 val = 1.0 - abs(n.yx);
			//n.xy = (n.zz < float2(0.0, 0.0) ? (n.xy >= 0.0 ? val : -val) : n.xy);

			// Optimized version of above code:
			float t = max(-n.z, 0.0);
			n.xy += n.xy >= 0.0 ? -t.xx : t.xx;

			return normalize(n);
		}

		float3 DecodeNormal(float3 packNormalWS)
		{
			float2 octNormalWS = Unpack888ToFloat2(packNormalWS);
			return UnpackNormalOctQuadEncode(octNormalWS * 2.0 - 1.0);
		}

	ENDCG

	SubShader {
		ZTest Always Cull Off ZWrite Off

		// 0: hbao pass (lowest quality)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		3
				#define STEPS			2
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 1: hbao pass (low quality)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		4
				#define STEPS			3
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 2: hbao pass (medium quality)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		6
				#define STEPS			4
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 3: hbao pass (high quality)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		8
				#define STEPS			4
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 4: hbao pass (highest quality)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		8
				#define STEPS			6
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 5: hbao pass (lowest quality / deinterleaved)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		3
				#define STEPS			2
				#define DEINTERLEAVED	1
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 6: hbao pass (low quality / deinterleaved)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		4
				#define STEPS			3
				#define DEINTERLEAVED	1
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 7: hbao pass (medium quality / deinterleaved)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		6
				#define STEPS			4
				#define DEINTERLEAVED	1
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 8: hbao pass (high quality / deinterleaved)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		8
				#define STEPS			4
				#define DEINTERLEAVED	1
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 9: hbao pass (highest quality / deinterleaved)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DIRECTIONS		8
				#define STEPS			6
				#define DEINTERLEAVED	1
				#include "HBAO_frag.cginc"

			ENDCG
		}

		// 10: deinterleave depth 2x2
		Pass {
			CGPROGRAM

				#pragma vertex vert_mesh
				#pragma fragment frag

				#define DOWNSCALING_FACTOR		2
				#include "HBAO_DeinterleaveDepth_frag.cginc"

			ENDCG
		}

		// 11: deinterleave depth 4x4
		Pass {
			CGPROGRAM

				#pragma vertex vert_mesh
				#pragma fragment frag

				#define DOWNSCALING_FACTOR		4
				#include "HBAO_DeinterleaveDepth_frag.cginc"

			ENDCG
		}

		// 12: deinterleave normals 2x2
		Pass {
			CGPROGRAM

				#pragma vertex vert_mesh
				#pragma fragment frag

				#define DOWNSCALING_FACTOR		2
				#include "HBAO_DeinterleaveNormals_frag.cginc"

			ENDCG
		}

		// 13: deinterleave normals 4x4
		Pass {
			CGPROGRAM

				#pragma vertex vert_mesh
				#pragma fragment frag

				#define DOWNSCALING_FACTOR		4
				#include "HBAO_DeinterleaveNormals_frag.cginc"

			ENDCG
		}

		// 14: atlassing input layer to output
		Pass {
			CGPROGRAM

				#pragma vertex vert_atlas
				#pragma fragment frag

				half4 frag(v2f i) : SV_Target {
					return tex2Dlod(_MainTex, float4(i.uv2, 0, 0));
				}

			ENDCG
		}

		// 15: reinterleave 2x2 from atlas
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DOWNSCALING_FACTOR		2
				#include "HBAO_Reinterleave_frag.cginc"

			ENDCG
		}

		// 16: reinterleave 4x4 from atlas
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define DOWNSCALING_FACTOR		4
				#include "HBAO_Reinterleave_frag.cginc"

			ENDCG
		}

		// 17: blur X pass (narrow)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		2
				#include "HBAO_BlurX_frag.cginc"

			ENDCG
		}

		// 18: blur X pass (medium)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		3
				#include "HBAO_BlurX_frag.cginc"

			ENDCG
		}

		// 19: blur X pass (wide)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		4
				#include "HBAO_BlurX_frag.cginc"

			ENDCG
		}

		// 20: blur X pass (extra wide)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		5
				#include "HBAO_BlurX_frag.cginc"

			ENDCG
		}

		// 21: blur Y pass (narrow)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		2
				#include "HBAO_BlurY_frag.cginc"

			ENDCG
		}

		// 22: blur Y pass (medium)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		3
				#include "HBAO_BlurY_frag.cginc"

			ENDCG
		}

		// 23: blur Y pass (wide)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		4
				#include "HBAO_BlurY_frag.cginc"

			ENDCG
		}

		// 24: blur Y pass (extra wide)
		Pass {
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#define KERNEL_RADIUS		5
				#include "HBAO_BlurY_frag.cginc"

			ENDCG
		}

		// 25: composite pass
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
							
				half4 frag (v2f i) : SV_Target {
					half4 ao = FetchOcclusion(i.uv2);
					half4 col = FetchSceneColor(i.uv);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					col.rgb *= aoColor;
				#if COLOR_BLEEDING_ON
					return half4(col.rgb + (1 - ao.rgb), col.a);
				#else
					return col;
				#endif
				}
				
			ENDCG
		}

		// 26: composite pass (MultiBounce)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				half4 frag(v2f i) : SV_Target {
					half4 ao = FetchOcclusion(i.uv2);
					half4 col = FetchSceneColor(i.uv);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					col.rgb *= lerp(aoColor, MultiBounceAO(ao.a, lerp(col.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence);
				#if COLOR_BLEEDING_ON
					return half4(col.rgb + (1 - ao.rgb), col.a);
				#else
					return col;
				#endif
				}

			ENDCG
		}

		// 27: show pass (AO only)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				
				half4 frag (v2f i) : SV_Target {
					half4 ao = FetchOcclusion(i.uv2);
					half4 col = FetchSceneColor(i.uv);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					return half4(aoColor, 1.0);
				}
				
			ENDCG
		}

		// 28: show pass (AO only MultiBounce)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				half4 frag(v2f i) : SV_Target {
					half4 ao = FetchOcclusion(i.uv2);
					half4 col = FetchSceneColor(i.uv);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					return half4(lerp(aoColor, MultiBounceAO(ao.a, lerp(col.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence), 1.0);
				}

			ENDCG
		}

		// 29: show pass (Color Bleeding only)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
							
				half4 frag (v2f i) : SV_Target {
					half4 ao = FetchOcclusion(i.uv2);
					return lerp(half4(0.0, 0.0, 0.0, 1.0), half4(1 - ao.rgb, 1.0), _ColorBleedSaturation);
				}
				
			ENDCG
		}

		// 30: show pass (split without AO / with AO)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				
				half4 frag (v2f i) : SV_Target {
					half4 col = FetchSceneColor(i.uv);
					if (i.uv.x <= 0.4985) {
						return col;
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 1.0);
					}
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					ao = half4(aoColor, 1.0);
					return col * ao;
				}
				
			ENDCG
		}

		// 31: show pass (split without AO / with AO MultiBounce)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				half4 frag(v2f i) : SV_Target {
					half4 col = FetchSceneColor(i.uv);
					if (i.uv.x <= 0.4985) {
						return col;
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 1.0);
					}
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					col.rgb *= lerp(aoColor, MultiBounceAO(ao.a, lerp(col.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence);
					return col;
				}

			ENDCG
		}

		// 32: show pass (split with AO / AO only)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				
				half4 frag (v2f i) : SV_Target {
					half4 col = FetchSceneColor(i.uv);
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					ao = half4(aoColor, 1.0);
					if (i.uv.x <= 0.4985) {
						return col * ao;
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 1.0);
					}
					return ao;
				}
				
			ENDCG
		}

		// 33: show pass (split with AO / AO only MultiBounce)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				half4 frag(v2f i) : SV_Target {
					half4 col = FetchSceneColor(i.uv);
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					ao = half4(lerp(aoColor, MultiBounceAO(ao.a, lerp(col.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence), 1);
					if (i.uv.x <= 0.4985) {
						return col * ao;
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 1.0);
					}
					return ao;
				}

			ENDCG
		}

		// 34: show pass (split without AO / AO only)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				
				half4 frag (v2f i) : SV_Target {
					half4 col = FetchSceneColor(i.uv);
					if (i.uv.x <= 0.4985) {
						return col;
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 1.0);
					}
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					ao = half4(aoColor, 1.0);
					return ao;
				}
				
			ENDCG
		}

		// 35: show pass (split without AO / AO only MultiBounce)
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				half4 frag(v2f i) : SV_Target {
					half4 col = FetchSceneColor(i.uv);
					if (i.uv.x <= 0.4985) {
						return col;
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 1.0);
					}
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					ao = half4(lerp(aoColor, MultiBounceAO(ao.a, lerp(col.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence), 1);
					return ao;
				}

			ENDCG
		}

		// 36: combine deferred
		Pass {
			CGPROGRAM

                #pragma vertex vert_mesh
                #pragma fragment frag

                #include "HBAO_Deferred.cginc"

			ENDCG
		}

		// 37: combine deferred HDR (multiplicative blending)
		Pass {
			Blend DstColor Zero, DstAlpha Zero
			CGPROGRAM

				#pragma vertex vert_mesh
				#pragma fragment frag_blend

				#include "HBAO_Deferred.cginc"

			ENDCG
		}

		// 38: combine integrated
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#include "HBAO_Integrated.cginc"

			ENDCG
		}

		// 39: combine integrated MultiBounce
		Pass {
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_multibounce

				#include "HBAO_Integrated.cginc"

			ENDCG
		}

		// 40: combine integrated HDR (multiplicative blending)
		Pass {
			Blend DstColor Zero
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend

				#include "HBAO_Integrated.cginc"

			ENDCG
		}

		// 41: combine integrated HDR MultiBounce (multiplicative blending)
		Pass {
			Blend DstColor Zero
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend_multibounce

				#include "HBAO_Integrated.cginc"

			ENDCG
		}

		// 42: combine color bleeding HDR (additive blending)
		Pass {
			Blend One One
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend

				half4 frag_blend(v2f i) : SV_Target {
					return half4(1 - FetchOcclusion(i.uv2).rgb, 1.0);
				}

			ENDCG
		}

		// 43: AO debug pass (additive blending)
		Pass {
			Blend One Zero
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend

				half4 frag_blend(v2f i) : SV_Target {
					if (i.uv.x <= 0.4985) {
						clip(-1);
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 0);
					}
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					return half4(aoColor, 0);
				}

			ENDCG
		}

		// 44: AO debug pass MultiBounce (additive blending)
		Pass {
			Blend One Zero
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend

				half4 frag_blend(v2f i) : SV_Target {
					if (i.uv.x <= 0.4985) {
						clip(-1);
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 0);
					}
				#if UNITY_SINGLE_PASS_STEREO
					float2 uv = UnityStereoTransformScreenSpaceTex(i.uv2);
					half3 rt3 = tex2D(_rt3Tex, uv);
				#else
					half3 rt3 = tex2D(_rt3Tex, i.uv2);
				#endif
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					return half4(lerp(aoColor, MultiBounceAO(ao.a, lerp(rt3.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence), 0);
				}

			ENDCG
		}

		// 45: AO debug pass (multiplicative blending)
		Pass {
			Blend DstColor Zero
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend

				half4 frag_blend(v2f i) : SV_Target {
					if (i.uv.x <= 0.4985) {
						clip(-1);
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 0);
					}
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					return half4(aoColor, 0);
				}

			ENDCG
		}

		// 46: AO debug pass MultiBounce (multiplicative blending)
		Pass {
			Blend DstColor Zero
			ColorMask RGB
			CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag_blend

				half4 frag_blend(v2f i) : SV_Target {
					if (i.uv.x <= 0.4985) {
						clip(-1);
					}
					if (i.uv.x > 0.4985 && i.uv.x < 0.5015) {
						return half4(0.0, 0.0, 0.0, 0);
					}
				#if UNITY_SINGLE_PASS_STEREO
					float2 uv = UnityStereoTransformScreenSpaceTex(i.uv2);
					half3 rt3 = tex2D(_rt3Tex, uv);
				#else
					half3 rt3 = tex2D(_rt3Tex, i.uv2);
				#endif
					half4 ao = FetchOcclusion(i.uv2);
					half3 aoColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), ao.a);
					return half4(lerp(aoColor, MultiBounceAO(ao.a, lerp(rt3.rgb, _BaseColor.rgb, _BaseColor.rgb)), _MultiBounceInfluence), 0);
				}

			ENDCG
		}

	}

	FallBack off
}
