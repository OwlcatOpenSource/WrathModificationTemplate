Shader "Owlcat/Utils/CubemapArrayPreview"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "OwlcatPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 4.5

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "../../ShaderLibrary/Input.hlsl"
			#include "../../ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL0;
            };

            struct v2f
            {
				float3 normal : TEXCOORD0;
				float3 view : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

			TEXTURECUBE_ARRAY(_PreviewCubemapArray);
			float _Mip;
			float _Intensity;
			float _Slice;
			float4x4 _CubemapRotation;

            v2f vert (appdata v)
            {
                v2f o;

				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				o.view = normalize(_WorldSpaceCameraPos - TransformObjectToWorld(v.vertex.xyz).xyz);
				//o.vertex = mul(_CubemapRotation, float4(v.vertex.xyz, 1));
				o.normal = mul((float3x3)_CubemapRotation, v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
				float3 reflectVector = mul((float3x3)_CubemapRotation, normalize(reflect(-i.view, i.normal)));
				float4 col = SAMPLE_TEXTURECUBE_ARRAY_LOD(_PreviewCubemapArray, s_trilinear_clamp_sampler, reflectVector, _Slice, _Mip);
                return col;
            }
            ENDHLSL
        }
    }
}
