#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

TEXTURE2D_HALF(_Source);
SamplerState sampler_LinearClamp;
uniform float4 _SrcScaleBias;
uniform float4 _SrcUvLimits; // {xy: max uv, zw: offset of blur for 1 texel }
uniform float _SourceMip;

struct Attributes
{
    uint vertexID : SV_VertexID;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 texcoord   : TEXCOORD0;
};

Varyings Vert(Attributes input)
{
    Varyings output;
    output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
    output.texcoord   = GetFullScreenTriangleTexCoord(input.vertexID) * _SrcScaleBias.xy + _SrcScaleBias.zw;
    return output;
}

#define NAN_COLOR float4(0.0, 0.0, 0.0, 0.0)

float4 StopNaN(float4 color)
{
    if (AnyIsNaN(color) || AnyIsInf(color))
        color = NAN_COLOR;

    return color;
}

float4 Frag(Varyings input) : SV_Target
{
    // Gaussian weights for 9 texel kernel from center textel to furthest texel. Keep in sync with ColorPyramid.compute
    const float gaussWeights[] = { 0.27343750, 0.21875000, 0.10937500, 0.03125000, 0.00390625 };

    float2 offset = _SrcUvLimits.zw;
    float2 offset1 = offset * (1.0 + (gaussWeights[2] / (gaussWeights[1] + gaussWeights[2])));
    float2 offset2 = offset * (3.0 + (gaussWeights[4] / (gaussWeights[3] + gaussWeights[4])));

    float2 uv_m2 = input.texcoord.xy - offset2;
    float2 uv_m1 = input.texcoord.xy - offset1;
    float2 uv_p0 = input.texcoord.xy;
    float2 uv_p1 = min(_SrcUvLimits.xy, input.texcoord.xy + offset1);
    float2 uv_p2 = min(_SrcUvLimits.xy, input.texcoord.xy + offset2);

    return
        + StopNaN(SAMPLE_TEXTURE2D_LOD(_Source, sampler_LinearClamp, uv_m2, _SourceMip)) * (gaussWeights[3] + gaussWeights[4])
        + StopNaN(SAMPLE_TEXTURE2D_LOD(_Source, sampler_LinearClamp, uv_m1, _SourceMip)) * (gaussWeights[1] + gaussWeights[2])
        + StopNaN(SAMPLE_TEXTURE2D_LOD(_Source, sampler_LinearClamp, uv_p0, _SourceMip)) *  gaussWeights[0]
        + StopNaN(SAMPLE_TEXTURE2D_LOD(_Source, sampler_LinearClamp, uv_p1, _SourceMip)) * (gaussWeights[1] + gaussWeights[2])
        + StopNaN(SAMPLE_TEXTURE2D_LOD(_Source, sampler_LinearClamp, uv_p2, _SourceMip)) * (gaussWeights[3] + gaussWeights[4]);
}