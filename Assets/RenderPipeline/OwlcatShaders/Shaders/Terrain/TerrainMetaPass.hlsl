#ifndef OWLCAT_TERRAIN_METAPASS_INCLUDED
#define OWLCAT_TERRAIN_METAPASS_INCLUDED

#include "TerrainInput.hlsl"
#include "../../ShaderLibrary/MetaInput.hlsl"

Varyings OwlcatVertexMeta(Attributes input)
{
    Varyings output;
    
    output.positionCS = MetaVertexPosition(input.positionOS, input.uvLM, input.uvDLM, unity_LightmapST, unity_DynamicLightmapST);
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    return output;
}

float4 OwlcatFragmentMeta(Varyings input) : SV_Target
{
    SurfaceData surfaceData = (SurfaceData)0;
	float4 mainTexSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    surfaceData.albedo = mainTexSample.rgb;
    surfaceData.smoothness = mainTexSample.a;
    surfaceData.metallic = SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, input.uv).r;

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, surfaceData.translucency, surfaceData.wrapDiffuseFactor, brdfData);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
    metaInput.SpecularColor = surfaceData.specular;
    metaInput.Emission = surfaceData.emission;

    return MetaFragment(metaInput);
}

#endif //OWLCAT_TERRAIN_METAPASS_INCLUDED
