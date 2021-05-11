Shader "Hidden/Owlcat/CopyDepthSimple"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
            ZTest Always
            Cull Off
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

            #pragma target 4.5

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "../../ShaderLibrary/Input.hlsl"
            #include "../../ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                uint vertexID : VERTEXID_SEMANTIC;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);

                return output;
            }

            float Frag(Varyings IN) : SV_Target
            {
                return LOAD_TEXTURE2D(_CameraDepthRT, uint2(IN.positionCS.xy)).x;
            }

			ENDHLSL
		}
	}
}
