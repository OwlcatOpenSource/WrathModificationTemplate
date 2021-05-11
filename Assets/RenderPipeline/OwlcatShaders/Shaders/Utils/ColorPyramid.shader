Shader "Hidden/Owlcat/ColorPyramid"
{
    SubShader
    {
        Tags{ "RenderPipeline" = "OwlcatPipeline" }

        Pass
        {
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
                #pragma target 4.5
                #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch
                #pragma vertex Vert
                #pragma fragment Frag
                #include "ColorPyramidPS.hlsl"
			ENDHLSL
        }

    }
        Fallback Off
}