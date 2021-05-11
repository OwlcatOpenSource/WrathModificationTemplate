Shader "Owlcat/Water"
{
	Properties
	{
        _TripleTapFreq("Triple Tap Sampling Frequency", float) = 1

		[TextureKeyword(_FLOWMAP)]
		[NoScaleOffset]
        _FlowMap("Flow Map", 2D) = "black" {}
        _FlowSpeed("Flow Speed", vector) = (1,1,0,0)
		[Toggle]_UvDirection("Alight Uv Direction To Flow", float) = 0

        [HDR]_BaseColor("Color", Color) = (1,1,1,1)

        [TextureKeyword(_NORMALMAP)]
        _BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1.0

        [Space]
        _Roughness("Roughness", Range(0, 1)) = 1
        _Metallic("Metallic", Range(0, 1)) = 0
		_WrapDiffuseFactor("Wrap Diffuse Factor (Forward Only)", Range(0, 1)) = 0

        [Space]
        _Density("Density", float) = .5
        _ShoreBlend("Shore Blend", float) = 1

        [PropertyGroup(FOAM_ON, foam)]_FoamEnabled("Foam", float) = 0
        [NoScaleOffset]
        _FoamMap("Foam Map", 2D) = "black" {}
        [NoScaleOffset]
        _FoamMaskMap("Foam Mask Map", 2D) = "black" {}
        _FoamMaskScale("Foam Mask Scale", float) = 1
        [NoScaleOffset]
        _FoamDensityRamp("Foam Density Ramp", 2D) = "black" {}
        _FoamStrength("Foam Strength", float) = 1
        _FoamDepthPower("Foam Depth Power", float) = 1        

		[PropertyGroup(_DOUBLESIDED_ON, doubleSided)]_DoubleSided("Double Sided", float) = 0
		[Enum(Flip, 0, Mirror, 1, None, 2)] _DoubleSidedNormalMode("Double sided normal mode", Float) = 1
		[HideInInspector] _DoubleSidedConstants("_DoubleSidedConstants", Vector) = (1, 1, -1, 0)

		[PropertyGroup(DISTORTION_ON, _DistortionDoesNotUseAlpha, _DistortionThicknessScale, _Distortion, _DistortionColorFactor)]_DistortionEnabled("Distortion", float) = 0
		[Enum(Alpha Is Common Transparency, 0, Alpha Is Distortion Mask, 1)]_DistortionDoesNotUseAlpha("Alpha Mode", float) = 1
		_DistortionThicknessScale("Thickness Scale", Range(0, 1)) = 1
		_Distortion("Distortion Scale", float) = 1
		_DistortionColorFactor("Distortion Color Factor", Range(0,1)) = .5

        [PropertyGroup(_TRANSLUCENT, _Thickness, _ThicknessSharpness, Translucency)]_Translucent("Translucency", float) = 0
        _Thickness("Thickness", Range(0, 1)) = 1
		_TranslucencyColor("Translucency Color", Color) = (1,1,1,1)

		[Space]
		[Space]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)] _ReceiveShadows("Receive Shadows", float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[Toggle]_ReceiveDecals("Receive Decals", float) = 0

		[HideInInspector]_StencilRef("Stencil Ref", float) = 0
		[HideInInspector] _QueueOffset("Render Queue Offset", float) = 0

        // blend mode
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _ZTest("__zt", Float) = 3.0 // Equal for Opaque
        [HideInInspector] _CullMode("__cullMode", Float) = 2.0

		// ObsoleteProperties needs to alphatested baked GI
		[HideInInspector] _MainTex("BaseMap (RGB)", 2D) = "grey" {}
		[HideInInspector] _Color("Main Color", Color) = (1,1,1,1)
	}
	SubShader
	{
		Tags {"RenderType" = "Opaque" "RenderPipeline" = "OwlcatPipeline" "IgnoreProjector" = "True"}
		LOD 100

		Pass
		{
			Cull [_CullMode]

            Tags { "LightMode" = "SceneSelectionPass"}
            Name "SceneSelectionPass"

			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex GBufferVertex
			#pragma fragment GBufferFragment

            // -------------------------------------
            // Material Keywords
			#pragma shader_feature_local _FLOWMAP
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
			#pragma shader_feature_local _DISSOLVE_NOISEMAP
            #pragma shader_feature_local FOAM_ON
			#pragma shader_feature_local INDIRECT_INSTANCING

			// -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma target 4.5

            #define PASS_SCENESELECTIONPASS
            #define WRAP_DIFFUSE
			
			#include "WaterGBufferPass.hlsl"
			#pragma editor_sync_compilation
			ENDHLSL
		}

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
			#pragma shader_feature_local _FLOWMAP
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _TRANSLUCENT
			#pragma shader_feature_local _DISSOLVE_NOISEMAP
            #pragma shader_feature_local FOAM_ON

			#pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF

			#pragma shader_feature_local INDIRECT_INSTANCING

			// -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			// -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEFERRED_ON

			#pragma target 4.5

            #define PASS_GBUFFER
            #define WRAP_DIFFUSE
			
			#include "WaterGBufferPass.hlsl"
			ENDHLSL
		}

        Pass
		{
			Cull [_CullMode]
            ZClip On
            ZWrite Off
            ZTest [_ZTest]
            Blend[_SrcBlend][_DstBlend]

            Tags { "LightMode" = "ForwardLit"}
            Name "FORWARD LIT"
			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex ForwardLitVertex
			#pragma fragment ForwardLitFragment

            // -------------------------------------
            // Material Keywords
			#pragma shader_feature_local _FLOWMAP
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _TRANSLUCENT
            #pragma shader_feature_local _TRANSPARENT_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _DISSOLVE_NOISEMAP

            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
			#pragma shader_feature_local DISTORTION_ON
            #pragma shader_feature_local FOAM_ON
			#pragma shader_feature_local INDIRECT_INSTANCING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ SHADOWS_HARD SHADOWS_SOFT
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS

			#pragma target 4.5

            #define PASS_FORWARD_LIT
            #define WRAP_DIFFUSE

			#if defined(_TRANSPARENT_ON) || defined(DISTORTION_ON)
				#define SUPPORT_FOG_OF_WAR
			#endif

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "WaterForwardPass.hlsl"
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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _GPU_SKINNING
			#pragma shader_feature_local INDIRECT_INSTANCING

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma target 4.5

            #define PASS_DEBUG_ADDITIONAL
			
			#include "../../Debugging/DebugAdditionalPass.hlsl"
			ENDHLSL
		}
	}
}
