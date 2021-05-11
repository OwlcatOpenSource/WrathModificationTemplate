//
// This file was automatically generated. Please don't edit by hand.
//

#ifndef LIGHTDATA_CS_HLSL
#define LIGHTDATA_CS_HLSL
//
// Owlcat.Runtime.Visual.RenderPipeline.Lighting.LightVolumeType:  static fields
//
#define LIGHTVOLUMETYPE_CONE (0)
#define LIGHTVOLUMETYPE_SPHERE (1)
#define LIGHTVOLUMETYPE_BOX (2)
#define LIGHTVOLUMETYPE_COUNT (3)

//
// Owlcat.Runtime.Visual.RenderPipeline.Lighting.GPULightType:  static fields
//
#define GPULIGHTTYPE_DIRECTIONAL (0)
#define GPULIGHTTYPE_SPOT (1)
#define GPULIGHTTYPE_POINT (2)
#define GPULIGHTTYPE_COUNT (3)

//
// Owlcat.Runtime.Visual.RenderPipeline.Lighting.LightFalloffType:  static fields
//
#define LIGHTFALLOFFTYPE_INVERSE_SQUARED (0)
#define LIGHTFALLOFFTYPE_LEGACY (1)

// Generated from Owlcat.Runtime.Visual.RenderPipeline.Lighting.ClusterData
// PackingRules = Exact
struct ClusterData
{
    uint offset;
    uint count;
};

// Generated from Owlcat.Runtime.Visual.RenderPipeline.Lighting.LightVolumeData
// PackingRules = Exact
struct LightVolumeData
{
    float3 positionVS;
    float3 directionVS;
    uint volumeType;
    float range;
    float spotAngleCos;
    float spotAngleSin;
};

// Generated from Owlcat.Runtime.Visual.RenderPipeline.Lighting.LightData
// PackingRules = Exact
struct LightData
{
    float3 position;
    uint flags;
    float3 color;
    float shadowStrength;
    float4 attenuations;
    float3 spotDir;
    int shadowDataIndex;
    uint shadowMaskSelector;
    float innerRadius;
    float2 unused;
};

// Generated from Owlcat.Runtime.Visual.RenderPipeline.Lighting.DepthSliceData
// PackingRules = Exact
struct DepthSliceData
{
    int zBinOffset;
    int zBinCount;
    float zNear;
    float zFar;
    float2 halfTexelSizeNear;
    float2 halfTexelSizeFar;
};

//
// Accessors for Owlcat.Runtime.Visual.RenderPipeline.Lighting.ClusterData
//
uint GetOffset(ClusterData value)
{
    return value.offset;
}
uint GetCount(ClusterData value)
{
    return value.count;
}

#endif
