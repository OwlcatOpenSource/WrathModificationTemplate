#ifndef OWLCAT_LIT_META_PASS_INCLUDED
#define OWLCAT_LIT_META_PASS_INCLUDED

#include "LitInput.hlsl"
#include "../../ShaderLibrary/MetaInput.hlsl"

Varyings OwlcatVertexMeta(Attributes input)
{
    Varyings output;
    
    output.positionCS = MetaVertexPosition(input.positionOS, input.uvLM, input.uvDLM, unity_LightmapST, unity_DynamicLightmapST);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    return output;
}

float4 OwlcatFragmentMeta(Varyings input) : SV_Target
{
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, 0, surfaceData);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, surfaceData.translucency, surfaceData.wrapDiffuseFactor, brdfData);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
    metaInput.SpecularColor = surfaceData.specular;
    metaInput.Emission = surfaceData.emission * _EmissionColorScaleMeta;

    return MetaFragment(metaInput);
}

#endif // OWLCAT_LIT_META_PASS_INCLUDED
