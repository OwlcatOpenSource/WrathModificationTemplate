#ifndef HBAO_BLURX_FRAG_INCLUDED
#define HBAO_BLURX_FRAG_INCLUDED

#include "HBAO_Blur.cginc"

	half4 frag (v2f i) : SV_Target {
		return ComputeBlur(i.uv, float2((_ScreenParams.z - 1.0), 0));
	}

#endif // HBAO_BLURX_FRAG_INCLUDED
