#ifndef OWLCAT_SHADOWINPUT_INCLUDED
#define OWLCAT_SHADOWINPUT_INCLUDED

#include "../../Shadows/ShadowData.cs.hlsl"

StructuredBuffer<ShadowData> _ShadowDataBuffer : register(t5);
StructuredBuffer<ShadowMatrix> _ShadowMatricesBuffer : register(t6);

TEXTURE2D(_ShadowmapRT);
SAMPLER_CMP(sampler_ShadowmapRT);
TEXTURE2D_ARRAY(_ScreenSpaceShadowmapRT);

#define MAX_SHADOWMAP_ENTRIES 64

CBUFFER_START(ShadowCommonBuffer)
float4 _ShadowmapRT_TexelSize;
int _ShadowCurrentAlgorithm;
float2 _ShadowFadeDistanceScaleAndBias;
float3 _FaceVectors[4];
CBUFFER_END

CBUFFER_START(ShadowCasterBuffer)
float4 _LightDirection;
float3 _Clips[8];
int _ShadowEntryIndex;
int _FaceId;
float _PunctualNearClip;
int _ShadowFaceCount;
CBUFFER_END

//
// UnityEngine.Experimental.Rendering.GPUShadowAlgorithm:  static fields
//
#define GPUSHADOWALGORITHM_PCF_1TAP (0)
#define GPUSHADOWALGORITHM_PCF_9TAP (1)
#define GPUSHADOWALGORITHM_PCF_TENT_3X3 (2)
#define GPUSHADOWALGORITHM_PCF_TENT_5X5 (3)
#define GPUSHADOWALGORITHM_PCF_TENT_7X7 (4)

#endif // OWLCAT_SHADOWINPUT_INCLUDED
