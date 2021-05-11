#ifndef OWLCAT_UNLIT_INPUT_INCLUDED
#define OWLCAT_UNLIT_INPUT_INCLUDED

#include "../../ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseMap_TexelSize;
half4 _BaseColor;
half _Cutoff;
half _Glossiness;
half _Metallic;
CBUFFER_END

#endif // OWLCAT_UNLIT_INPUT_INCLUDED
