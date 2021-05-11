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

#ifndef HBAO_BLUR_INCLUDED
#define HBAO_BLUR_INCLUDED

#if COLOR_BLEEDING_ON
	inline void FetchAoAndDepth(float2 uv, inout half4 ao, inout float depth) {
		// References: https://docs.unity3d.com/Manual/SL-PlatformDifferences.html
#ifdef UNITY_SINGLE_PASS_STEREO
		float2 uvDepth = UnityStereoScreenSpaceUVAdjust(uv, _CameraDepthTexture_ST) * _TargetScale.xy;
		ao = tex2Dlod(_MainTex, float4(UnityStereoScreenSpaceUVAdjust(uv, _MainTex_ST), 0, 0));
#else
		float2 uvDepth = uv * _TargetScale.xy;
		ao = tex2Dlod(_MainTex, float4(uv, 0, 0));
#endif // UNITY_SINGLE_PASS_STEREO
#if ORTHOGRAPHIC_PROJECTION_ON
		depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uvDepth);
#if defined(UNITY_REVERSED_Z)
		depth = 1 - depth;
#endif // UNITY_REVERSED_Z
		depth = _ProjectionParams.y + depth * (_ProjectionParams.z - _ProjectionParams.y);
#else
		depth = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uvDepth));
#endif // ORTHOGRAPHIC_PROJECTION_ON
	}

    inline float CrossBilateralWeight(float r, float d, float d0) {
		const float BlurSigma = (float)KERNEL_RADIUS * 0.5;
		const float BlurFalloff = 1.0 / (2.0*BlurSigma*BlurSigma);

    	float dz = (d0 - d) * _BlurSharpness;
		return exp2(-r*r*BlurFalloff - dz*dz);
    }

	inline void ProcessSample(float4 ao, float z, float r, float d0, inout half4 totalAO, inout float totalW) {
		float w = CrossBilateralWeight(r, d0, z);
		totalW += w;
		totalAO += w * ao;
	}

	inline void ProcessRadius(float2 uv0, float2 deltaUV, float d0, inout half4 totalAO, inout float totalW) {
		half4 ao;
		float z;
		float2 uv;
		UNITY_UNROLL
		for (int r = 1; r <= KERNEL_RADIUS; r++) {
			uv = uv0 + r * deltaUV;
			FetchAoAndDepth(uv, ao, z);
			ProcessSample(ao, z, r, d0, totalAO, totalW);
		}
	}

	inline half4 ComputeBlur(float2 uv0, float2 deltaUV) {
		half4 totalAO;
		float depth;
		FetchAoAndDepth(uv0, totalAO, depth);
		float totalW = 1.0;
		
		ProcessRadius(uv0, -deltaUV, depth, totalAO, totalW);
		ProcessRadius(uv0, deltaUV, depth, totalAO, totalW);

		totalAO /= totalW;
		return totalAO;
	}

#else
	inline void FetchAoAndDepth(float2 uv, inout half ao, inout float2 depth) {
#if UNITY_SINGLE_PASS_STEREO
		float3 aod = tex2Dlod(_MainTex, float4(UnityStereoScreenSpaceUVAdjust(uv, _MainTex_ST), 0, 0)).rga;
#else
		float3 aod = tex2Dlod(_MainTex, float4(uv, 0, 0)).rga;
#endif
		ao = aod.z;
		depth = aod.xy;
	}

    inline float CrossBilateralWeight(float r, float d, float d0) {
		const float BlurSigma = (float)KERNEL_RADIUS * 0.5;
		const float BlurFalloff = 1.0 / (2.0*BlurSigma*BlurSigma);

    	float dz = (d0 - d) * _ProjectionParams.z * _BlurSharpness;
		return exp2(-r*r*BlurFalloff - dz*dz);
    }

	inline void ProcessSample(float2 aoz, float r, float d0, inout half totalAO, inout float totalW) {
		float w = CrossBilateralWeight(r, d0, aoz.y);
		totalW += w;
		totalAO += w * aoz.x;
	}

	inline void ProcessRadius(float2 uv0, float2 deltaUV, float d0, inout half totalAO, inout float totalW) {
		half ao; 
		float z;
		float2 d, uv;
		UNITY_UNROLL
		for (int r = 1; r <= KERNEL_RADIUS; r++) {
			uv = uv0 + r * deltaUV;
			FetchAoAndDepth(uv, ao, d);
			z = DecodeFloatRG(d);
			ProcessSample(float2(ao, z), r, d0, totalAO, totalW);
		}
	}

	inline half4 ComputeBlur(float2 uv0, float2 deltaUV) {
		half totalAO;
		float2 depth;
		FetchAoAndDepth(uv0, totalAO, depth);
		float d0 = DecodeFloatRG(depth);
		float totalW = 1.0;
		
		ProcessRadius(uv0, -deltaUV, d0, totalAO, totalW);
		ProcessRadius(uv0, deltaUV, d0, totalAO, totalW);

		totalAO /= totalW;
		return half4(depth, 1.0, totalAO);
	}
#endif // COLOR_BLEEDING_ON

#endif // HBAO_BLUR_INCLUDED
