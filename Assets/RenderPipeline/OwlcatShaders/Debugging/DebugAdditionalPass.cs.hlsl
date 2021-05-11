#ifndef OWLCAT_DEBUG_ADDITIONAL_PASS_INCLUDED
#define OWLCAT_DEBUG_ADDITIONAL_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

#include "DebugInput.hlsl"
#include "../ShaderLibrary/Input.hlsl"
#include "../ShaderLibrary/Core.hlsl"

struct Attributes
{
    float4 positionOS           : POSITION;
    float3 normalOS             : NORMAL;
    float2 texcoord             : TEXCOORD0;
    float2 lightmapUV           : TEXCOORD1;
    #ifdef _GPU_SKINNING
        float4 blendWeights     : BLENDWEIGHTS0;
        uint4 blendIndices      : BLENDINDICES0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS           : SV_POSITION;
    float3 positionWS           : TEXCOORD2;
    float3 positionVS           : TEXCOORD3;
    float3 normalWS              : TEXCOORD4;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings DebugVertex(Attributes input)
{
    Varyings output = (Varyings) 0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    #ifdef TERRAIN_DEBUG
        TerrainInstancing(input.positionOS, input.normalOS, input.texcoord);
    #endif

    #ifdef _GPU_SKINNING
        input.positionOS.xyz = Skin(input.positionOS.xyz, input.blendWeights, input.blendIndices);
    #endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

    output.positionWS = vertexInput.positionWS;
    output.positionVS = vertexInput.positionVS;
    output.positionCS = vertexInput.positionCS;

    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    return output;
}

float4 DebugFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float result = 1.0 / 255.0;
    return result * _DebugOverdrawChannelMask;
}

#endif //OWLCAT_DEBUG_ADDITIONAL_PASS_INCLUDED
