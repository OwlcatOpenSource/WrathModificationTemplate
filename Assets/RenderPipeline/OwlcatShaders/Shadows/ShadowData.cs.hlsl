//
// This file was automatically generated. Please don't edit by hand.
//

#ifndef SHADOWDATA_CS_HLSL
#define SHADOWDATA_CS_HLSL
// Generated from Owlcat.Runtime.Visual.RenderPipeline.Shadows.ShadowData
// PackingRules = Exact
struct ShadowData
{
    float4 matrixIndices;
    float4 atlasScaleOffset;
    int shadowFlags;
    int screenSpaceMask;
    float2 unused;
};

// Generated from Owlcat.Runtime.Visual.RenderPipeline.Shadows.ShadowMatrix
// PackingRules = Exact
struct ShadowMatrix
{
    float4x4 worldToShadow;
    float3 spherePosition;
    float sphereRadius;
    float sphereRadiusSq;
    float3 lightDirection;
    float normalBias;
    float depthBias;
    float2 unused;
};


#endif
