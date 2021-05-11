#ifndef HBAO_DEINTERLEAVEDEPTH_FRAG_INCLUDED
#define HBAO_DEINTERLEAVEDEPTH_FRAG_INCLUDED

	DeinterleavedOutput frag(v2f i) {
		DeinterleavedOutput o;

		float2 pos = floor(i.uv2 * _LayerRes_TexelSize.zw) * DOWNSCALING_FACTOR;
		float2 uv00 = (pos + _Deinterleaving_Offset00 + 0.5) * _FullRes_TexelSize.xy * _TargetScale.xy;
		float2 uv10 = (pos + _Deinterleaving_Offset10 + 0.5) * _FullRes_TexelSize.xy * _TargetScale.xy;
		float2 uv01 = (pos + _Deinterleaving_Offset01 + 0.5) * _FullRes_TexelSize.xy * _TargetScale.xy;
		float2 uv11 = (pos + _Deinterleaving_Offset11 + 0.5) * _FullRes_TexelSize.xy * _TargetScale.xy;

#if ORTHOGRAPHIC_PROJECTION_ON
		float z00 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv00);
		float z10 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv10);
		float z01 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv01);
		float z11 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv11);
#if defined(UNITY_REVERSED_Z)
		z00 = 1 - z00;
		z10 = 1 - z10;
		z01 = 1 - z01;
		z11 = 1 - z11;
#endif // UNITY_REVERSED_Z
		o.Z00 = _ProjectionParams.y + z00 * (_ProjectionParams.z - _ProjectionParams.y);
		o.Z10 = _ProjectionParams.y + z10 * (_ProjectionParams.z - _ProjectionParams.y);
		o.Z01 = _ProjectionParams.y + z01 * (_ProjectionParams.z - _ProjectionParams.y);
		o.Z11 = _ProjectionParams.y + z11 * (_ProjectionParams.z - _ProjectionParams.y);
#else
		o.Z00 = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv00)).rrrr;
		o.Z10 = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv10)).rrrr;
		o.Z01 = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv01)).rrrr;
		o.Z11 = DECODE_EYEDEPTH(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv11)).rrrr;
#endif
		return o;
	}

#endif // HBAO_DEINTERLEAVEDEPTH_FRAG_INCLUDED
