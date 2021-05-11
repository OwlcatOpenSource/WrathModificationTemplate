//----------------------------------------------------------------------------------
//
// Copyright (c) 2014, NVIDIA CORPORATION. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//  * Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//  * Neither the name of NVIDIA CORPORATION nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//----------------------------------------------------------------------------------

#ifndef HBAO_FRAG_INCLUDED
#define HBAO_FRAG_INCLUDED

	inline float3 FetchViewPos(float2 uv) {
		// References: https://docs.unity3d.com/Manual/SL-PlatformDifferences.html
#ifdef UNITY_SINGLE_PASS_STEREO
		float2 uvDepth = UnityStereoScreenSpaceUVAdjust(uv, _CameraDepthTexture_ST) * _TargetScale.xy;
#else
		float2 uvDepth = uv * _TargetScale.xy;
#endif // UNITY_SINGLE_PASS_STEREO
#if ORTHOGRAPHIC_PROJECTION_ON
		float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uvDepth);
#if defined(UNITY_REVERSED_Z)
		z = 1 - z;
#endif // UNITY_REVERSED_Z
		z = _ProjectionParams.y + z * (_ProjectionParams.z - _ProjectionParams.y); // near + depth * (far - near)
#else
		float z = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uvDepth));
#endif // ORTHOGRAPHIC_PROJECTION_ON
		return float3((uv * _UVToView.xy + _UVToView.zw) * z, z);
	}

	inline float3 FetchLayerViewPos(float2 uv) {
		float z = SAMPLE_DEPTH_TEXTURE(_DepthTex, uv);
		return float3((uv * _UVToView.xy + _UVToView.zw) * z, z);
	}

	inline float Falloff(float distanceSquare) {
		// 1 scalar mad instruction
		return distanceSquare * _NegInvRadius2 + 1.0;
	}

	inline float ComputeAO(float3 P, float3 N, float3 S) {
		float3 V = S - P;
		float VdotV = dot(V, V);
		float NdotV = dot(N, V) * rsqrt(VdotV);

		// Use saturate(x) instead of max(x,0.f) because that is faster on Kepler
		return saturate(NdotV - _AngleBias) * saturate(Falloff(VdotV));
	}

	inline float3 MinDiff(float3 P, float3 Pr, float3 Pl) {
		float3 V1 = Pr - P;
		float3 V2 = P - Pl;
		return (dot(V1, V1) < dot(V2, V2)) ? V1 : V2;
	}

	inline float2 RotateDirections(float2 dir, float2 rot) {
		return float2(dir.x * rot.x - dir.y * rot.y,
					  dir.x * rot.y + dir.y * rot.x);
	}

#if COLOR_BLEEDING_ON
	static float2 cbUVs[DIRECTIONS * STEPS];
	static float cbContribs[DIRECTIONS * STEPS];
#endif

	half4 frag(v2f i, UNITY_VPOS_TYPE screenPos : VPOS) : SV_Target {

#if DEINTERLEAVED
		float3 P = FetchLayerViewPos(i.uv2);
#else
		float3 P = FetchViewPos(i.uv2);
#endif

		clip(_MaxDistance - P.z);

		float stepSize = min((_Radius / P.z), _MaxRadiusPixels) / (STEPS + 1.0);

#if DEINTERLEAVED
		// (cos(alpha), sin(alpha), jitter)
		float3 rand = _Jitter.xyz;

		float3 N = tex2D(_NormalsTex, i.uv2).rgb * 2.0 - 1.0;
	#else
		// (cos(alpha), sin(alpha), jitter)
		float3 rand = tex2D(_NoiseTex, screenPos.xy / _NoiseTexSize).rgb;

		float2 InvScreenParams = _ScreenParams.zw - 1.0;

	#if NORMALS_RECONSTRUCT
		float3 Pr, Pl, Pt, Pb;
		Pr = FetchViewPos(i.uv2 + float2(InvScreenParams.x, 0));
		Pl = FetchViewPos(i.uv2 + float2(-InvScreenParams.x, 0));
		Pt = FetchViewPos(i.uv2 + float2(0, InvScreenParams.y));
		Pb = FetchViewPos(i.uv2 + float2(0, -InvScreenParams.y));
		float3 N = normalize(cross(MinDiff(P, Pr, Pl), MinDiff(P, Pt, Pb)));
	#else
		#if NORMALS_CAMERA
			#if UNITY_SINGLE_PASS_STEREO
				float3 N = DecodeViewNormalStereo(tex2D(_CameraDepthNormalsTexture, UnityStereoScreenSpaceUVAdjust(i.uv2, _CameraDepthTexture_ST)));
			#else
				float3 N = DecodeViewNormalStereo(tex2D(_CameraDepthNormalsTexture, i.uv2));
			#endif // UNITY_SINGLE_PASS_STEREO
		#else
			#if UNITY_SINGLE_PASS_STEREO
				float3 N = DecodeNormal(tex2D(_CameraGBufferTexture2, UnityStereoScreenSpaceUVAdjust(i.uv2, _CameraDepthTexture_ST)).rgb);
			#else
				float3 N = DecodeNormal(tex2D(_CameraGBufferTexture2, i.uv2).rgb);
			#endif // UNITY_SINGLE_PASS_STEREO
			N = mul((float3x3)_WorldToCameraMatrix, N);
		#endif // NORMALS_CAMERA
		N = float3(N.x, -N.yz);
	#endif // NORMALS_RECONSTRUCT
#endif // DEINTERLEAVED

		const float alpha = 2.0 * UNITY_PI / DIRECTIONS;
		float ao = 0;

		UNITY_UNROLL
		for (int d = 0; d < DIRECTIONS; ++d) {
			float angle = alpha * float(d);

			// Compute normalized 2D direction
			float cosA, sinA;
			sincos(angle, sinA, cosA);
			float2 direction = RotateDirections(float2(cosA, sinA), rand.xy);

			// Jitter starting sample within the first step
			float rayPixels = (rand.z * stepSize + 1.0);

			UNITY_UNROLL
			for (int s = 0; s < STEPS; ++s) {

#if DEINTERLEAVED
				float2 snappedUV = round(rayPixels * direction) * _LayerRes_TexelSize.xy + i.uv2;
				float3 S = FetchLayerViewPos(snappedUV);
#else
				float2 snappedUV = round(rayPixels * direction) * InvScreenParams + i.uv2;
				float3 S = FetchViewPos(snappedUV);
#endif
				rayPixels += stepSize;

				float contrib = ComputeAO(P, N, S);
#if OFFSCREEN_SAMPLES_CONTRIB
				float2 offscreenAmount = _OffscreenSamplesContrib * (snappedUV - saturate(snappedUV) != 0 ? 1 : 0);
				contrib = max(contrib, offscreenAmount.x);
				contrib = max(contrib, offscreenAmount.y);
#endif
				ao += contrib;
#if COLOR_BLEEDING_ON
				int sampleIdx = d * s;
				cbUVs[sampleIdx] = snappedUV;
				cbContribs[sampleIdx] = contrib;
#endif
			}
		}

		ao *= (_AOmultiplier / (STEPS * DIRECTIONS));

		float fallOffStart = _MaxDistance - _DistanceFalloff;
		ao = lerp(saturate(1.0 - ao), 1.0, saturate((P.z - fallOffStart) / (_MaxDistance - fallOffStart)));

#if COLOR_BLEEDING_ON
		half3 col = half3(0.0, 0.0, 0.0);
		UNITY_UNROLL
		for (int s = 0; s < DIRECTIONS * STEPS; s += 2) {
#if UNITY_SINGLE_PASS_STEREO
			float2 uvCB = UnityStereoScreenSpaceUVAdjust(float2(cbUVs[s].x, cbUVs[s].y * _MainTex_TexelSize.y * _MainTex_TexelSize.w), _MainTex_ST);
#else
			float2 uvCB = float2(cbUVs[s].x, cbUVs[s].y * _MainTex_TexelSize.y * _MainTex_TexelSize.w);
#endif // UNITY_SINGLE_PASS_STEREO
			half3 emission = tex2D(_MainTex, uvCB).rgb;
			half average = (emission.x + emission.y + emission.z) / 3;
			half scaledAverage = saturate((average - _ColorBleedBrightnessMaskRange.x) / (_ColorBleedBrightnessMaskRange.y - _ColorBleedBrightnessMaskRange.x + 1e-6));
			half maskMultiplier = 1 - (scaledAverage * _ColorBleedBrightnessMask);
			col += emission * cbContribs[s] * maskMultiplier;
		}
		col /= DIRECTIONS * STEPS;
#if DEFERRED_SHADING_ON
#if UNITY_SINGLE_PASS_STEREO
		half3 albedo = tex2D(_CameraGBufferTexture0, UnityStereoScreenSpaceUVAdjust(i.uv2, _MainTex_ST)).rgb * 0.8 + 0.2;
#else
		half3 albedo = tex2D(_CameraGBufferTexture0, i.uv2).rgb * 0.8 + 0.2;
#endif // UNITY_SINGLE_PASS_STEREO
		col = saturate(1 - lerp(dot(col, 0.333).xxx, col * _AlbedoMultiplier * albedo, _ColorBleedSaturation));
#else
		col = saturate(1 - lerp(dot(col, 0.333).xxx, col, _ColorBleedSaturation));
#endif
#else
		half3 col = half3(EncodeFloatRG(saturate(P.z * (1.0 / _ProjectionParams.z))), 1.0);
#endif
		return half4(col, ao);
	}

#endif // HBAO_FRAG_INCLUDED
