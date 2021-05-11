#ifndef HBAO_DEFERRED_INCLUDED
#define HBAO_DEFERRED_INCLUDED

    struct CombinerOutput {
	    half4 gbuffer0 : SV_Target0;	// albedo (RGB), occlusion (A)
	    half4 gbuffer3 : SV_Target1;	// emission (RGB), unused(A)
    };

    CombinerOutput frag(v2f i) {
		half4 occ = FetchOcclusion(i.uv2);
		half3 ao = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), occ.a);

	    CombinerOutput o;
#if UNITY_SINGLE_PASS_STEREO
		float2 uv = UnityStereoTransformScreenSpaceTex(i.uv2);
	    o.gbuffer0 = tex2D(_rt0Tex, uv);
	    o.gbuffer3 = tex2D(_rt3Tex, uv);
#else
		o.gbuffer0 = tex2D(_rt0Tex, i.uv2);
		o.gbuffer3 = tex2D(_rt3Tex, i.uv2);
#endif
	    o.gbuffer0.a *= occ.a;
	    o.gbuffer3.rgb = -log2(o.gbuffer3.rgb);
		half emission = saturate((o.gbuffer3.r + o.gbuffer3.g + o.gbuffer3.b) / 3);
		o.gbuffer3.rgb *= lerp(ao, half3(1.0, 1.0, 1.0), emission);
#if COLOR_BLEEDING_ON
	    o.gbuffer3.rgb += 1 - occ.rgb;
#endif
	    o.gbuffer3.rgb = exp2(-o.gbuffer3.rgb);

	    return o;
    }

    CombinerOutput frag_blend(v2f i) {
		half4 occ = FetchOcclusion(i.uv2);
	    half3 ao = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), occ.a);

#if UNITY_SINGLE_PASS_STEREO
		float2 uv = UnityStereoTransformScreenSpaceTex(i.uv2);
		half3 rt3 = tex2D(_rt3Tex, uv);
#else
		half3 rt3 = tex2D(_rt3Tex, i.uv2);
#endif
	    CombinerOutput o;
	    o.gbuffer0 = half4(1.0, 1.0, 1.0, occ.a);
		half emission = saturate((rt3.x + rt3.y + rt3.z) / 3);
		o.gbuffer3 = half4(lerp(ao, half3(1.0, 1.0, 1.0), emission), 0);

	    return o;
    }

#endif // HBAO_DEFERRED_INCLUDED
