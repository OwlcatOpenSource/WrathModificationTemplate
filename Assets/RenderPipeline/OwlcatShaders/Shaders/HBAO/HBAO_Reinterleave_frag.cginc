#ifndef HBAO_REINTERLEAVE_FRAG_INCLUDED
#define HBAO_REINTERLEAVE_FRAG_INCLUDED

	half4 frag(v2f i) : SV_Target {
		float2 offset = fmod(floor(i.uv2 * _FullRes_TexelSize.zw), DOWNSCALING_FACTOR);
		float2 uv = (floor(i.uv2 * _LayerRes_TexelSize.zw) + (offset * _LayerRes_TexelSize.zw) + 0.5) * _FullRes_TexelSize.xy;
		return tex2Dlod(_MainTex, float4(uv, 0, 0));
	}

#endif // HBAO_REINTERLEAVE_FRAG_INCLUDED
