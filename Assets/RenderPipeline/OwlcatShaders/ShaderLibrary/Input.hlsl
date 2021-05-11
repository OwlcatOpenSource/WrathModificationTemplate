#ifndef OWLCAT_INPUT_INCLUDED
#define OWLCAT_INPUT_INCLUDED

#define MAX_VISIBLE_LIGHTS 512
#define MAX_Z_SLICES_COUNT 64
#define MAX_DIRECTIONAL_LIGHTS_COUNT 4
#define DEFERRED_TILE_SIZE 16
#define SSR_MAX_DEPTH_LOD_COUNT 16

#include "../Lighting/LightData.cs.hlsl"

struct InputData
{
    float3 positionWS;
    int2 positionSS;
    float3 normalWS;
    float3 viewDirectionWS;
    float linearDepth;
    float fogCoord;
    float3 bakedGI;
    float4 shadowMask;
    int depthSliceIndex;
    uint3 clusterUv;
};

// shared samplers
SAMPLER(s_point_clamp_sampler);
SAMPLER(s_linear_clamp_sampler);
SAMPLER(s_linear_repeat_sampler);
SAMPLER(s_trilinear_clamp_sampler);

TEXTURE2D(_CameraColorRT);
TEXTURE2D(_CameraAlbedoRT);
TEXTURE2D(_CameraNormalsRT);
TEXTURE2D(_CameraColorPyramidRT);
TEXTURE2D(_CameraBakedGIRT);
TEXTURE2D(_CameraShadowmaskRT);
TEXTURE2D(_CameraTranslucencyRT);
TEXTURE2D(_CameraDeferredReflectionsRT);
TEXTURE2D_FLOAT(_CameraDepthRT);
TEXTURE2D(_DistortionVectorsRT);

TEXTURE2D(_FogOfWarMask);
TEXTURE2D(_OccludedDepthRT);

#ifdef OCCLUDED_OBJECT_CLIP
    TEXTURE3D(_OccludedObjectNoiseMap3D);
#endif

Buffer<int> _LightIndicesBuffer;
StructuredBuffer<LightData> _LightDataBuffer;
StructuredBuffer<DepthSliceData> _DepthSliceBuffer;
StructuredBuffer<ClusterData> _ClusterDataBuffer;
Buffer<uint> _GlobalLightIndicesBuffer;

#ifdef INDIRECT_INSTANCING
	#include "../IndirectRendering/IndirectInstanceData.cs.hlsl"
    StructuredBuffer<IndirectInstanceData> _IndirectInstanceDataBuffer;
	StructuredBuffer<float4> _LightProbesBuffer;
    Buffer<uint> _ArgsBuffer;
    Buffer<uint> _IsVisibleBuffer;
    uniform int _ArgsOffset;
#endif

///////////////////////////////////////////////////////////////////////////////
//                      Constant Buffers                                     //
///////////////////////////////////////////////////////////////////////////////

CBUFFER_START(_PerCamera)
float4 _GlossyEnvironmentColor;

float4x4 _InvCameraViewProj;

// Базис камеры в пространстве реконструкции
float3 _CamBasisUp;
float3 _CamBasisSide;
float3 _CamBasisFront;

int _ColorPyramidLodCount;
int _DepthPyramidLodCount;
float4 _DepthPyramidMipRects[SSR_MAX_DEPTH_LOD_COUNT];
float2 _DepthPyramidSamplingRatio;

// Clusters
float4 _Clusters;

// Lights
int _DirectionalLightsCount;
int _VisibleLightsCount;

// Fog Of War
float4 _FogOfWarMask_ST;
float4 _FogOfWarColor;
float _FogOfWarGlobalFlag;
float2 _FogOfWarMaskSize;

// Occluded Objects
float _OccludedObjectClipNoiseTiling;
float _OccludedObjectClipTreshold;
float _OccludedObjectAlphaScale;
float _OccludedObjectClipNearCameraDistance;
float _OccludedObjectHighlightingFeatureEnabled;

// Vertex Animation Wind Parameters
#if defined(VERTEX_ANIMATION_ENABLED)
    #include "Noise/SimplexNoise2D.hlsl"
    #define WIND_STRENGTH_OCTAVES_COUNT 2
    #define WIND_SHIFT_OCTAVES_COUNT 2
    float _GlobalWindEnabled;
    float _StrengthNoiseWeight;
    float _StrengthNoiseContrast;
    float2 _WindVector;
    float4 _CompressedStrengthOctaves[WIND_STRENGTH_OCTAVES_COUNT];
    float4 _CompressedShiftOctaves[WIND_SHIFT_OCTAVES_COUNT];
#endif
CBUFFER_END

CBUFFER_START(_LightBuffer)

float4 _MainLightPosition;
float4 _MainLightColor;

float4 _AdditionalLightsCount;
float4 _AdditionalLightsPosition[MAX_VISIBLE_LIGHTS];
float4 _AdditionalLightsColor[MAX_VISIBLE_LIGHTS];
float4 _AdditionalLightsAttenuation[MAX_VISIBLE_LIGHTS];
float4 _AdditionalLightsSpotDir[MAX_VISIBLE_LIGHTS];
float4 _AdditionalLightsOcclusionProbes[MAX_VISIBLE_LIGHTS];
CBUFFER_END

#define UNITY_MATRIX_M     unity_ObjectToWorld
#define UNITY_MATRIX_I_M   unity_WorldToObject
#define UNITY_MATRIX_V     unity_MatrixV
#define UNITY_MATRIX_I_V   unity_MatrixInvV
#define UNITY_MATRIX_P     OptimizeProjectionMatrix(glstate_matrix_projection)
#define UNITY_MATRIX_I_P   ERROR_UNITY_MATRIX_I_P_IS_NOT_DEFINED
#define UNITY_MATRIX_VP    unity_MatrixVP
#define UNITY_MATRIX_I_VP  _InvCameraViewProj
#define UNITY_MATRIX_MV    mul(UNITY_MATRIX_V, UNITY_MATRIX_M)
#define UNITY_MATRIX_T_MV  transpose(UNITY_MATRIX_MV)
#define UNITY_MATRIX_IT_MV transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V))
#define UNITY_MATRIX_MVP   mul(UNITY_MATRIX_VP, UNITY_MATRIX_M)

#include "UnityInput.hlsl"

// если включен INDIRECT_INSTANCING, выключаем INSTANCING_ON и переопределяем макросы из UnityInstancing.hlsl
#if defined(INDIRECT_INSTANCING)
    #ifdef INSTANCING_ON
        #undef INSTANCING_ON
    #endif
#endif
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

// redefine instanced built-in variables
// before(!) SpaceTransforms.hlsl include
#if defined(INDIRECT_INSTANCING)
	
	#ifdef DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID
		#undef DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID
	#endif

	#ifdef DEFAULT_UNITY_SETUP_INSTANCE_ID
		#undef DEFAULT_UNITY_SETUP_INSTANCE_ID
	#endif

	#ifdef UNITY_TRANSFER_INSTANCE_ID
		#undef UNITY_TRANSFER_INSTANCE_ID
	#endif

    #ifdef SHADER_API_PSSL
        #define DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID uint instanceID;
        #define UNITY_GET_INSTANCE_ID(input)    _GETINSTANCEID(input)
    #else
        #define DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID uint instanceID : SV_InstanceID;
        #define UNITY_GET_INSTANCE_ID(input)    input.instanceID
    #endif

    #if !defined(UNITY_VERTEX_INPUT_INSTANCE_ID)
        #define UNITY_VERTEX_INPUT_INSTANCE_ID DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID
    #endif

    // A global instance ID variable that functions can directly access.
    static uint unity_InstanceID;
    int unity_BaseInstanceID;
    int unity_InstanceCount;

    void UnitySetupInstanceID(uint inputInstanceID)
    {
        unity_InstanceID = inputInstanceID + unity_BaseInstanceID;
    }

    #define DEFAULT_UNITY_SETUP_INSTANCE_ID(input)          { UnitySetupInstanceID(UNITY_GET_INSTANCE_ID(input));}
    #define UNITY_TRANSFER_INSTANCE_ID(input, output)   output.instanceID = UNITY_GET_INSTANCE_ID(input)

    #if !defined(UNITY_SETUP_INSTANCE_ID)
        #define UNITY_SETUP_INSTANCE_ID(input) DEFAULT_UNITY_SETUP_INSTANCE_ID(input)
    #endif

    #ifdef SHADER_API_METAL
        #define GET_INDIRECT_INSTANCE_ID _IsVisibleBuffer[unity_InstanceID]
    #else
        #define GET_INDIRECT_INSTANCE_ID _IsVisibleBuffer[unity_InstanceID + _ArgsBuffer[_ArgsOffset]]
    #endif
    #undef UNITY_MATRIX_M
    #undef UNITY_MATRIX_I_M
    #define UNITY_MATRIX_M _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID].objectToWorld;
    #define UNITY_MATRIX_I_M _IndirectInstanceDataBuffer[GET_INDIRECT_INSTANCE_ID].worldToObject;
    #define UNITY_ASSUME_UNIFORM_SCALING
#endif

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

#endif // OWLCAT_INPUT_INCLUDED
