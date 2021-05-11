Shader "Hidden/Owlcat/TerrainBaseGen"
{
    Properties
    {
		[HideInInspector] _DstBlend("DstBlend", Float) = 0.0
    }
    SubShader
    {
		Tags{ "SplatCount" = "256" }

		HLSLINCLUDE

        #pragma target 4.5
        #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

        // Terrain builtin keywords
        //#pragma shader_feature _TERRAIN_MASKS

        #include "TerrainInput.hlsl"
		#include "TerrainCommon.hlsl"

        struct Attributes
		{
            float3 vertex : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float4 texcoord : TEXCOORD0;
        };

        #pragma vertex Vert
        #pragma fragment Frag

        float2 ComputeControlUV(float2 uv)
        {
            // adjust splatUVs so the edges of the terrain tile lie on pixel centers
            return (uv * (_SplatArray_TexelSize.zw - 1.0f) + 0.5f) * _SplatArray_TexelSize.xy;
        }

        Varyings Vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformWorldToHClip(input.vertex);
            output.texcoord.xy = TRANSFORM_TEX(input.texcoord, _SplatArray);
            output.texcoord.zw = ComputeControlUV(output.texcoord.xy);
            return output;
        }

        ENDHLSL

		Pass
        {
            Tags
            {
                "Name" = "_MainTex"
                "Format" = "ARGB32"
                "Size" = "1"
            }

            ZTest Always Cull Off ZWrite Off
            Blend One [_DstBlend]

            HLSLPROGRAM

            float4 Frag(Varyings input) : SV_Target
            {
				float4 mixedDiffuse;
				float4 mixedMasks;
				float3 positionOS = 0;
				float3 vertexNormal = 0;

				SplatmapMix(input.texcoord.xy, positionOS, vertexNormal, mixedDiffuse, mixedMasks);

				float3 albedo = mixedDiffuse.rgb;
				float smoothness = 1.0 - mixedMasks.r;
				return float4(albedo, 1);
            }

            ENDHLSL
        }
    }
}
