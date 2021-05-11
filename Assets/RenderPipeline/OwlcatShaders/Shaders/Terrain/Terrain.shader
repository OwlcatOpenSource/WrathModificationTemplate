Shader "Owlcat/Terrain"
{
    Properties
    {
        // set by terrain engine
        [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Splat0("Layer 0 (R)", 2D) = "grey" {}
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
        [HideInInspector] _Mask3("Mask 3 (A)", 2D) = "black" {}
        [HideInInspector] _Mask2("Mask 2 (B)", 2D) = "black" {}
        [HideInInspector] _Mask1("Mask 1 (G)", 2D) = "black" {}
        [HideInInspector] _Mask0("Mask 0 (R)", 2D) = "black" {}
        [HideInInspector][Gamma] _Metallic0("Metallic 0", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic1("Metallic 1", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic2("Metallic 2", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic3("Metallic 3", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Smoothness0("Smoothness 0", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness1("Smoothness 1", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness2("Smoothness 2", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness3("Smoothness 3", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _TerrainMaxHeight("Max Height", float) = 0
        [HideInInspector] _ControlTexturesCount("Control Textures Count", float) = 0

        // used in fallback on old cards & base map
        [HideInInspector] _MainTex("BaseMap (RGB)", 2D) = "grey" {}
        [HideInInspector] _Color("Main Color", Color) = (1,1,1,1)

		[HideInInspector]_StencilRef("Stencil Ref", float) = 0

        _AlphaBlendFactor("Alpha Blend Factor", Range(0.00001, 1)) = 0.05

        // TODO: Implement ShaderGUI for the shader and display the checkbox only when instancing is enabled.
        [TerrainInstancedNormal(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)] _TERRAIN_INSTANCED_PERPIXEL_NORMAL("Enable Instanced Per-pixel Normal", Float) = 1
        
		[PropertyGroup(_TRIPLANAR, triplanar)]_TriplanarEnabled("Triplanar Enabled", float) = 0
        _TriplanarTightenFactor("Triplanar Tighten Factor", Range(0, 1)) = 0.576

        [Toggle]_ReceiveDecals("Receive Decals", float) = 0
        [Toggle(_TERRAIN_MASKS)]_TerrainMasks("Masks texture enabled", float) = 0

		[ToggleOff(_RECEIVE_SHADOWS_OFF)] _ReceiveShadows("Receive Shadows", float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
    }

    SubShader
    {
		// This tags allow to use the shader replacement features
        Tags
		{
			"Queue" = "Geometry-100"
			"RenderType" = "Opaque"
			"RenderPipeline" = "OwlcatPipeline"
			"IgnoreProjector" = "False"
			//"SplatCount" = "256"
		}

        Pass
        {
			Stencil
			{
				Ref [_StencilRef]
				Comp always
				Pass replace
			}

            Name "GBuffer"
            Tags { "LightMode" = "GBuffer"}
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #define PASS_GBUFFER

            // -------------------------------------
            // Unity defined keywords
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

			// -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ DEFERRED_ON

            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL

            #pragma shader_feature_local _TRIPLANAR

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif

            #include "TerrainInput.hlsl"
            #include "TerrainGBufferPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            ZClip On
            ZWrite Off
            ZTest Equal

            Name "ForwardLit"
            Tags { "LightMode" = "ForwardLit"}
            HLSLPROGRAM
			#pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #define PASS_FORWARD_LIT
			//#define SUPPORT_FOG_OF_WAR

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ SHADOWS_HARD SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #pragma shader_feature_local _TERRAIN_MASKS
            #pragma shader_feature_local _TRIPLANAR
			#pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
            #include "TerrainInput.hlsl"
            #include "TerrainForwardLitPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
			Cull [_CullMode]
			ZClip [_ZClip]
            ColorMask 0
            Offset [_OffsetFactor], [_OffsetUnits]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex Vert
            #pragma fragment Frag

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            // -------------------------------------
            // Light types
            #pragma multi_compile _ GEOMETRY_CLIP

            #include "TerrainInput.hlsl"
            #include "TerrainShadowCasterPass.hlsl"
            ENDHLSL
        }

		Pass
		{
			ZTest Off
			Blend One One
			Cull [_CullMode]

            Tags { "LightMode" = "DebugAdditional"}
            Name "DEBUG ADDITIONAL"

			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex DebugVertex
			#pragma fragment DebugFragment

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
			#pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

			#pragma target 4.5

            #define PASS_DEBUG_ADDITIONAL
			#define TERRAIN_DEBUG
			
			#include "TerrainInput.hlsl"
			#include "TerrainCommon.hlsl"
			#include "../../Debugging/DebugAdditionalPass.hlsl"
			ENDHLSL
		}

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }
    Dependency "BaseMapShader" = "Hidden/Owlcat/TerrainBase"

	// Unity генерирует BaseMap многопроходным рендером и кастомные свойства в шейдер не прокидываются
	// поэтому я оставил стандартный Standard-BaseGen.shader (его можно посмотреть в built-in shaders на сайте unity)
	// НО Hidden/Owlcat/TerrainBaseGen используется для подкраски травы
	//Dependency "BaseMapGenShader" = "Hidden/Owlcat/TerrainBaseGen"
}
