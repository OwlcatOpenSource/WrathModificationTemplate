#ifndef HBAO_BLURY_FRAG_INCLUDED
#define HBAO_BLURY_FRAG_INCLUDED

#include "HBAO_Blur.cginc"

	half4 frag (v2f i) : SV_Target {
		return ComputeBlur(i.uv, float2(0, (_ScreenParams.w - 1.0)));
	}

#endif // HBAO_BLURY_FRAG_INCLUDED
