Shader "Owlcat/Unlit"
{
    Properties
    {
        _BaseMap ("Albedo", 2D) = "white" {}
        [HDR]_BaseColor("Color", Color) = (1,1,1,1)

		[PropertyGroup(_Surface, blend)]_Surface("Transparent", float) = 0
		[Enum(Alpha, 0, Premultiply, 1, Additive, 2, AdditiveSoft, 3, AdditiveSoftSquare, 4, Multiply, 5)]_Blend("Blend", float) = 0

		[PropertyGroup(_ALPHATEST_ON, cutoff)]_Alphatest("Alpha Clip", float) = 0
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5

        [Toggle(OCCLUDED_OBJECT_CLIP)] _OccludedObjectClip("Occluded object clip", float) = 0.0

		[HideInInspector]_StencilRef("Stencil Ref", float) = 0
		[HideInInspector] _QueueOffset("Render Queue Offset", float) = 0

        // blend mode
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _ZTest("__zt", Float) = 3.0 // Equal for Opaque
        [HideInInspector] _CullMode("__cullMode", Float) = 2.0

		// ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        [HideInInspector] _SampleGI("SampleGI", float) = 0.0 // needed from bakedlit
    }
    SubShader
    {
        Tags {"RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "OwlcatPipeline"}
		LOD 100

		Pass
        {
            Cull [_CullMode]
			Stencil
			{
				Ref [_StencilRef]
				Comp always
				Pass replace
			}

            Tags { "LightMode" = "GBuffer"}
            Name "GBUFFER"

			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex GBufferVertex
			#pragma fragment GBufferFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local OCCLUDED_OBJECT_CLIP

			// -------------------------------------
            // Unity defined keywords

			// -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY
			#pragma multi_compile _ DEFERRED_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma target 4.5
			
            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "UnlitPasses.hlsl"
			ENDHLSL
        }

		Pass
		{
			Cull [_CullMode]
            ZClip On
            ZWrite Off
            ZTest [_ZTest]
            Blend[_SrcBlend][_DstBlend]

            Name "Unlit"
			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex UnlitVertex
			#pragma fragment UnlitFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _TRANSPARENT_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY

			#pragma target 4.5

			#if defined(_TRANSPARENT_ON)
				#define SUPPORT_FOG_OF_WAR
			#endif

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "UnlitPasses.hlsl"
			ENDHLSL
		}
    }
}
