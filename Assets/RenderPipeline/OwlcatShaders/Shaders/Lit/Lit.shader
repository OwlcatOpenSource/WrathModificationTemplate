Shader "Owlcat/Lit"
{
	Properties
	{
        [MainTexture]
		_BaseMap ("Albedo", 2D) = "white" {}
        [HDR][MainColor]_BaseColor("Color", Color) = (1,1,1,1)
        [Enum(Multiply, 0, Lerp, 1)]_BaseColorBlending("Color Blending", float) = 0

        [TextureKeyword(_NORMALMAP)]
        [NoScaleOffset]
        _BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1.0

        [TextureKeyword(_MASKSMAP)]
        [NoScaleOffset]
        _MasksMap("Masks (R - Roughness G - Emission B - Metallic A - Thickness)", 2D) = "black" {}

        _Roughness("Roughness", Range(0, 1)) = 1
        _Metallic("Metallic", Range(0, 1)) = 0
		_WrapDiffuseFactor("Wrap Diffuse Factor (binary if Deferred)", Range(0, 1)) = 0

		[PropertyGroup(_Surface, _blend)]_Surface("Transparent", float) = 0
		[Enum(Alpha, 0, Premultiply, 1, Additive, 2, AdditiveSoft, 3, AdditiveSoftSquare, 4, Multiply, 5)]_Blend("Blend", float) = 0

		[PropertyGroup(_DOUBLESIDED_ON, doubleSided)]_DoubleSided("Double Sided", float) = 0
		[Enum(Flip, 0, Mirror, 1, None, 2)] _DoubleSidedNormalMode("Double sided normal mode", Float) = 1
		[HideInInspector] _DoubleSidedConstants("_DoubleSidedConstants", Vector) = (1, 1, -1, 0)

		[PropertyGroup(_ALPHATEST_ON, cutoff)]_Alphatest("Alpha Clip", float) = 0
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5

		[PropertyGroup(_RimLighting, _RimColor, _RimPower)]_RimLighting("Rim Lighting", float) = 0    
        _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimPower("Rim Power", float) = 1

		[PropertyGroup(ADDITIONAL_ALBEDO, additionalAlbedo)]_AdditionalAlbedoEnabled("Additional Albedo", float) = 0
		_AdditionalAlbedoMap("Texture", 2D) = "white" {}
		_AdditionalAlbedoFactor("Factor", Range(0, 1)) = 0
		_AdditionalAlbedoColorScale("Color Scale", float) = 1
		_AdditionalAlbedoColorClamp("Color Clamp", float) = 1
		_AdditionalAlbedoAlphaScale("Alpha Scale", float) = 1
		_AdditionalAlbedoColor("Color", Color) = (1,1,1,1)

		[PropertyGroup(DISSOLVE_ON, dissolve)]_DissolveEnabled("Dissolve", float) = 0
		_DissolveMap("Dissolve Texture (R Channel)", 2D) = "white" {}
		_Dissolve("Dissolve Level", Range(0, 1)) = 0
		_DissolveWidth("Dissolve Width", Range(0,1)) = .1
		[ToggleOff]
		_DissolveCutout("Dissolve Cutout", float) = 1
		[ToggleOff]
		_DissolveEmission("Dissolve Emission", float) = 1
		_DissolveColor("Dissolve Color", Color) = (1,1,1,1)
		_DissolveColorScale("Dissolve Color Scale", float) = 1
		[TextureKeyword(_DISSOLVE_NOISEMAP)]
		_DissolveNoiseMap("Noise Map", 2D) = "black" {}
		_DissolveNoiseScale("Noise Scale", float) = 1

		[PropertyGroup(DISTORTION_ON, _DistortionDoesNotUseAlpha, _DistortionThicknessScale, _Distortion, _DistortionColorFactor)]_DistortionEnabled("Distortion", float) = 0
		[Enum(Alpha Is Common Transparency, 0, Alpha Is Distortion Mask, 1)]_DistortionDoesNotUseAlpha("Alpha Mode", float) = 1
		_DistortionThicknessScale("Thickness Scale", Range(0, 1)) = 1
		_Distortion("Distortion Scale", float) = 1
		_DistortionColorFactor("Distortion Color Factor", Range(0,1)) = .5

        [PropertyGroup(_TRANSLUCENT, _Thickness, _ThicknessSharpness, Translucency)]_Translucent("Translucency", float) = 0
        _Thickness("Thickness", Range(0, 1)) = 1
		_TranslucencyColor("Translucency Color", Color) = (1,1,1,1)

        [PropertyGroup(_EMISSION, _emission, pemission)]_Emission("Emission", float) = 0
        [NoScaleOffset]
        [TextureKeyword(_EMISSIONMAP)]_EmissionMap("Emission", 2D) = "white" {}
		[Enum(RGB, 0, Alpha, 1)]_EmissionMapUsage("Emission Map Usage", float) = 0
        _EmissionColor("Color", Color) = (1,1,1)
		_EmissionColorFactor("Color Factor", Range(0, 1)) = 0
		_EmissionColorScale("Intensity", float) = 1
		_EmissionAlbedoSuppression("Albedo Suppression", float) = 0
        [LightmapEmissionFlags]_LightmapEmissionFlags("Lightmap Emission Flags", float) = 0
		_EmissionColorScaleMeta("Lightmap Emission Color Scale", float) = 1

		[PropertyGroup(USE_GROUND_COLOR, groundColor)] _UseGroundColor("Use Ground Color (Grass and Details)", float) = 0
		_GroundColorPower("Ground Color Power", Range(0, 1)) = 1

        [PropertyGroup(VAT_ENABLED, vatMap, vatPos, vatPiv, vatNum, vatCurr, vatLerp, vatType)]_VatEnabled("VAT (Vertex Animation Texture)", float) = 0
        [Enum(Rigid, 0, Soft, 1, Fluid, 2)]_VatType("Simulation Type", float) = 0
        [NoScaleOffset]
        _PosVatMap("Position map", 2D) = "black" {}
        [NoScaleOffset]
        [TextureKeyword(_VAT_ROTATIONMAP)]_RotVatMap("Rotation map", 2D) = "black" {}
        _VatNumOfFrames("_numOfFrames", float) = 0
        _VatPosMin("_posMin", float) = 0
        _VatPosMax("_posMax", float) = 0
        _VatPivMin("_pivMin", float) = 0
        _VatPivMax("_pivMax", float) = 0
        //_VatTextureSizeX("_textureSizeX", float) = 0
        //_VatTextureSizeY("_textureSizeY", float) = 0
        //_VatPaddedSizeX("_paddedSizeX", float) = 0
        //_VatPaddedSizeY("_paddedSizeY", float) = 0
        //[Toggle]_VatPadPowTwo("_padPowTwo", float) = 0
        [Toggle]_VatLerp("Lerp Frames (Expensive)", float) = 0
        _VatCurrentFrame("Current Frame", float) = 0

        [PropertyGroup(VERTEX_ANIMATION_ENABLED, VaPrimaryFactor, VaSecondaryFactor, VaEdgeFlutter)]_VertexAnimationEnabled("Procedural Vertex Animation", float) = 0
        _VaPrimaryFactor("Primary Factor", Range(0, 1)) = 0
        _VaSecondaryFactor("Secondary Factor", Range(0, 1)) = 0
        _VaEdgeFlutter("Edge Flutter", Range(0, 1)) = 0

		[Space]
		[Space]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)] _ReceiveShadows("Receive Shadows", float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[Toggle]_ReceiveDecals("Receive Decals", float) = 0
        [Toggle(_GPU_SKINNING)] _GpuSkinning("GPU Skinning Enabled", float) = 0.0
        [KeywordPopup(None, PBD_NONE, Skinning, PBD_SKINNING, Mesh, PBD_MESH, Grass, PBD_GRASS)]_PbdMode("Position Based Dynamics Mode", float) = 0
        [Toggle(OCCLUDED_OBJECT_CLIP)] _OccludedObjectClip("Occluded object clip", float) = 0.0
        [Toggle(INDIRECT_INSTANCING)] _IndirectIstancing("Grass instancing", float) = 0.0
        [Toggle]_SpecialPostprocessFlag("Enable Special Postprocess", float) = 0

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
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _GPU_SKINNING
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP
			#pragma shader_feature_local _DISSOLVE_NOISEMAP
            #pragma shader_feature_local PBD_SKINNING
            #pragma shader_feature_local PBD_MESH
            #pragma shader_feature_local PBD_GRASS
            #pragma shader_feature_local USE_GROUND_COLOR
            #pragma shader_feature_local INDIRECT_INSTANCING
            #pragma shader_feature_local VERTEX_ANIMATION_ENABLED

			#pragma multi_compile __ DISSOLVE_ON
			#pragma multi_compile __ ADDITIONAL_ALBEDO

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
			
			#include "LitGBufferPass.hlsl"
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
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _EMISSIONMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _TRANSLUCENT
			#pragma shader_feature_local _DISSOLVE_NOISEMAP

            #pragma shader_feature_local _GPU_SKINNING
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP
			#pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local OCCLUDED_OBJECT_CLIP
            #pragma shader_feature_local PBD_SKINNING
            #pragma shader_feature_local PBD_MESH
            #pragma shader_feature_local PBD_GRASS
            #pragma shader_feature_local USE_GROUND_COLOR
            #pragma shader_feature_local INDIRECT_INSTANCING
            #pragma shader_feature_local VERTEX_ANIMATION_ENABLED

			#pragma multi_compile __ DISSOLVE_ON
			#pragma multi_compile __ ADDITIONAL_ALBEDO

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
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ DEFERRED_ON

			#pragma target 4.5

            #define PASS_GBUFFER
            #define WRAP_DIFFUSE
            #define PBD_SKINNING_NORM
            #define PBD_SKINNING_TANG
			
            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "LitGBufferPass.hlsl"
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
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _EMISSIONMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _TRANSLUCENT
            #pragma shader_feature_local _TRANSPARENT_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _DISSOLVE_NOISEMAP

            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _GPU_SKINNING
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP
			#pragma shader_feature_local DISTORTION_ON
            #pragma shader_feature_local PBD_SKINNING
            #pragma shader_feature_local PBD_MESH
            #pragma shader_feature_local PBD_GRASS
            #pragma shader_feature_local USE_GROUND_COLOR
            #pragma shader_feature_local INDIRECT_INSTANCING
            #pragma shader_feature_local VERTEX_ANIMATION_ENABLED

			#pragma multi_compile __ DISSOLVE_ON
			#pragma multi_compile __ ADDITIONAL_ALBEDO

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
            #define PBD_SKINNING_NORM
            #define PBD_SKINNING_TANG

			#if defined(_TRANSPARENT_ON) || defined(DISTORTION_ON)
				#define SUPPORT_FOG_OF_WAR
			#endif

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "LitForwardPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Cull [_CullMode]
            ZClip On
            ZWrite Off
			ZTest [_ZTest]
			Blend One One
			BlendOp Add, Max

            Tags { "LightMode" = "DistortionVectors"}
            Name "DISTORTION VECTORS"
			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex ForwardLitVertex
			#pragma fragment ForwardLitFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _TRANSLUCENT
            #pragma shader_feature_local _TRANSPARENT_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _DISSOLVE_NOISEMAP

            #pragma shader_feature_local _GPU_SKINNING
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP
			#pragma shader_feature_local DISTORTION_ON
            #pragma shader_feature_local PBD_SKINNING
            #pragma shader_feature_local PBD_MESH
            #pragma shader_feature_local PBD_GRASS
            #pragma shader_feature_local USE_GROUND_COLOR
            #pragma shader_feature_local INDIRECT_INSTANCING
            #pragma shader_feature_local VERTEX_ANIMATION_ENABLED

            #pragma multi_compile __ DISSOLVE_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS

			#pragma target 4.5

            #define PASS_DISTORTION_VECTORS

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "LitForwardPass.hlsl"
			ENDHLSL
		}

        Pass
        {
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
			Cull [_CullMode]
            ZClip [_ZClip]
            ColorMask 0
            Offset [_OffsetFactor], [_OffsetUnits]

            HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP
			#pragma shader_feature_local _DISSOLVE_NOISEMAP
            #pragma shader_feature_local PBD_SKINNING
            #pragma shader_feature_local PBD_MESH
            #pragma shader_feature_local PBD_GRASS
            #pragma shader_feature_local VERTEX_ANIMATION_ENABLED

			#pragma multi_compile __ DISSOLVE_ON

            // -------------------------------------
            // Light types
            #pragma multi_compile _ GEOMETRY_CLIP

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex Vertex
            #pragma fragment Fragment

            #define PASS_SHADOWCASTER

            #include "LitShadowCasterPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
		Pass
        {
            Name "META"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma only_renderers d3d11 vulkan ps4

            #pragma vertex OwlcatVertexMeta
            #pragma fragment OwlcatFragmentMeta

            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _EMISSIONMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "LitMetaPass.hlsl"

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
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP
            #pragma shader_feature_local PBD_SKINNING
            #pragma shader_feature_local PBD_MESH
            #pragma shader_feature_local PBD_GRASS
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
