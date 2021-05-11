#ifndef HBAO_DEINTERLEAVENORMALS_FRAG_INCLUDED
#define HBAO_DEINTERLEAVENORMALS_FRAG_INCLUDED

	inline float3 FetchViewPos(float2 uv) {
		// References: https://docs.unity3d.com/Manual/SL-PlatformDifferences.html
#if ORTHOGRAPHIC_PROJECTION_ON
		float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv * _TargetScale.xy);
#if defined(UNITY_REVERSED_Z)
		z = 1 - z;
#endif // UNITY_REVERSED_Z
		z = _ProjectionParams.y + z * (_ProjectionParams.z - _ProjectionParams.y);
#else
		float z = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv * _TargetScale.xy));
#endif // ORTHOGRAPHIC_PROJECTION_ON
		return float3((uv * _UVToView.xy + _UVToView.zw) * z, z);
	}

	inline float3 MinDiff(float3 P, float3 Pr, float3 Pl) {
		float3 V1 = Pr - P;
		float3 V2 = P - Pl;
		return (dot(V1, V1) < dot(V2, V2)) ? V1 : V2;
	}

	inline float4 FetchViewNormals(float2 uv) {
#if NORMALS_RECONSTRUCT
		float3 Pr, Pl, Pt, Pb;
		Pr = FetchViewPos(uv + float2(_FullRes_TexelSize.x, 0));
		Pl = FetchViewPos(uv + float2(-_FullRes_TexelSize.x, 0));
		Pt = FetchViewPos(uv + float2(0, _FullRes_TexelSize.y));
		Pb = FetchViewPos(uv + float2(0, -_FullRes_TexelSize.y));
		float3 P = FetchViewPos(uv);
		float3 N = normalize(cross(MinDiff(P, Pr, Pl), MinDiff(P, Pt, Pb)));
#else
#if NORMALS_CAMERA
		float3 N = DecodeViewNormalStereo(tex2D(_CameraDepthNormalsTexture, uv * _TargetScale.xy));
#else
		float3 N = DecodeNormal(tex2D(_CameraGBufferTexture2, uv * _TargetScale.xy).rgb);
		N = mul((float3x3)_WorldToCameraMatrix, N);
#endif // NORMALS_CAMERA
		N = float3(N.x, -N.yz);
#endif // NORMALS_RECONSTRUCT
		return float4(N, 0);
	}

	DeinterleavedOutput frag(v2f i) {
		DeinterleavedOutput o;

		float2 pos = floor(i.uv2 * _LayerRes_TexelSize.zw) * DOWNSCALING_FACTOR;
		float2 uv00 = (pos + _Deinterleaving_Offset00 + 0.5) * _FullRes_TexelSize.xy;
		float2 uv10 = (pos + _Deinterleaving_Offset10 + 0.5) * _FullRes_TexelSize.xy;
		float2 uv01 = (pos + _Deinterleaving_Offset01 + 0.5) * _FullRes_TexelSize.xy;
		float2 uv11 = (pos + _Deinterleaving_Offset11 + 0.5) * _FullRes_TexelSize.xy;

		o.Z00 = FetchViewNormals(uv00) * 0.5 + 0.5;
		o.Z10 = FetchViewNormals(uv10) * 0.5 + 0.5;
		o.Z01 = FetchViewNormals(uv01) * 0.5 + 0.5;
		o.Z11 = FetchViewNormals(uv11) * 0.5 + 0.5;

		return o;
	}

#endif // HBAO_DEINTERLEAVENORMALS_FRAG_INCLUDED
