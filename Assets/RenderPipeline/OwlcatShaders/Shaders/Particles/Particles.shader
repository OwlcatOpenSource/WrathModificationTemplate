Shader "Owlcat/Particles"
{
    Properties
    {
		[MainColor]
		_BaseColor("Color", Color) = (1,1,1,1)
		[MainTexture]
		_BaseMap ("Albedo", 2D) = "white" {}
		_UV0Speed("UV0 Speed", Vector) = (0,0,0,0)

		[TextureKeyword(_MASKSMAP)]
		[NoScaleOffset]
		_MasksMap("Masks (R - Roughness G - Emission B - Metallic A - Thickness)", 2D) = "white" {}

		[TextureKeyword(_ROUGHNESSMAP, 1)]
		[NoScaleOffset]
		_RoughnessMap("Roughness Map Override", 2D) = "white" {}

		[TextureKeyword(_METALLICMAP, 1)]
		[NoScaleOffset]
		_MetallicMap("Metallic Map Override", 2D) = "white" {}

		[TextureKeyword(_THICKNESSMAP, 1)]
		[NoScaleOffset]
		_ThicknessMap("Thickness Map Override", 2D) = "white" {}

		_Roughness("Roughness", Range(0, 1)) = 1
		_Metallic("Metallic", Range(0, 1)) = 0

		_AlphaScale("Alpha Scale", float) = 1
		_HdrColorScale("HDR Color Scale", float) = 1.0
		_HdrColorClamp("HDR Clamp", float) = 100.0

		_Cutoff("Cutout", Range(0, 1)) = .001
		_VirtualOffset("Virtual Offset", float) = 0
		[ToggleOff] _SubstractVertexAlpha("Substract Vertex Alpha", float) = 0
		[ToggleOff] _FogOfWarMaterialFlag("Fog Of War Affected", float) = 1
		_FogInfluence("Unity Fog Influence", Range(0, 1)) = .5

		[PropertyGroup(COLOR_ALPHA_RAMP, ramp)]_ColorAlphaRampEnabled("Color Alpha Ramp", float) = 0
		_ColorAlphaRamp("Color Alpha Ramp", 2D) = "white" {}
		_RampScrollSpeed("Ramp Scroll Speed", float) = 0
		_RampAlbedoWeight("Ramp -> Albedo x Ramp Lerp", Range(0, 1)) = 0

		[PropertyGroup(TEXTURE1_ON, tex1, uv1)]_Tex1Enabled("Texture1", float) = 0
		_MainTex1("Texture", 2D) = "white" {}
		_UV1Speed("UV1 Speed", Vector) = (0,0,0,0)
		[ToggleOff] _ApplyTexSheetUvTex1("Apply Texture Sheet Animation", float) = 1
		_MainTex1Weight("Main Tex 1 Weight", float) = 1.0
		[Enum(Lerp RGBA,1,Lerp RGB Multiply A,2)] _Tex1MixMode("Mix Mode", float) = 1.0

		[PropertyGroup(RADIAL_ALPHA, radialalpha)]_RadialAlphaEnabled("Radial Alpha", float) = 0
		_RadialAlphaGradientStart("Gradient Start Point", float) = 1
		_RadialAlphaGradientPower("Gradient Pow", float) = 1
		[ToggleOff]_RadialAlphaSubstract("Substract Radial Alpha", float) = 0

		[PropertyGroup(NOISE0_ON, noise0, uvCorrection, noiseOffset)]_Noise0Enabled("Noise 0", float) = 0
		_Noise0Tex("Noise 0", 2D) = "black" {}
		_Noise0Scale("Noise 0 Scale", float) = 0.0
		_Noise0IDSpeedScale("Noise 0 ID Scale", float) = 1.0
		_Noise0Speed("Noise 0 Speed", Vector) = (0,0,0,0)
		[ToggleOff] _ApplyTexSheetUvNoise0("Apply Texture Sheet Animation", float) = 1
		[Toggle(NOISE_UV_CORRECTION)]_NoiseUvCorrectionEnabled("Noise UV Correction (NEED UV2)", float) = 0
		[Toggle]_RandomizeNoiseOffset("Randomize Noise Offset (Check Particle Material Controller If Enabled)", float) = 0

		[PropertyGroup(NOISE1_ON, noise1, uvCorrection, noiseOffset)]_Noise1Enabled("Noise 1", float) = 0
		_Noise1Tex("Noise 1", 2D) = "black" {}
		_Noise1Scale("Noise 1 Scale", float) = 0.0
		_Noise1IDSpeedScale("Noise 1 ID Scale", float) = 1.0
		_Noise1Speed("Noise 1 Speed", Vector) = (0,0,0,0)
		[ToggleOff] _ApplyTexSheetUvNoise1("Apply Texture Sheet Animation", float) = 1

		[PropertyGroup(_Surface, blend)]_Surface("Transparent", float) = 0
		[Enum(Alpha, 0, Premultiply, 1, Additive, 2, AdditiveSoft, 3, AdditiveSoftSquare, 4, Multiply, 5)]_Blend("Blend", float) = 0

		[PropertyGroup(_DOUBLESIDED_ON, doubleSided)]_DoubleSided("Double Sided", float) = 1
		[Enum(Flip, 0, Mirror, 1, None, 2)] _DoubleSidedNormalMode("Double sided normal mode", Float) = 1
		[HideInInspector] _DoubleSidedConstants("_DoubleSidedConstants", Vector) = (1, 1, -1, 0)

        [PropertyGroup(_EMISSION, emission)]_Emission("Emission", float) = 0
        [TextureKeyword(_EMISSIONMAP)]_EmissionMap("Emission", 2D) = "white" {}
		_UvEmissionSpeed("UV Emission Speed", Vector) = (0,0,0,0)
		[ToggleOff]_ApplyTexSheetUvEmission("Apply Texture Sheet Animation", float) = 1
		[Enum(RGB, 0, Alpha, 1)]_EmissionMapUsage("Emission Map Usage", float) = 0
        _EmissionColor("Color", Color) = (1,1,1)
		_EmissionColorFactor("Color Factor", Range(0, 1)) = 0
		_EmissionColorScale("Intensity", float) = 1
		_EmissionAlbedoSuppression("Albedo Suppression", float) = 0

		[PropertyGroup(DISTORTION_ON, _DistortionDoesNotUseAlpha, _DistortionThicknessScale, _Distortion, _DistortionColorFactor, _DistortionOffset)]_DistortionEnabled("Distortion", float) = 0
		[Enum(Alpha Is Common Transparency, 0, Alpha Is Distortion Mask, 1)]_DistortionDoesNotUseAlpha("Alpha Mode", float) = 0
		_DistortionThicknessScale("Thickness Scale", Range(0, 1)) = 1
		_Distortion("Distortion Scale", float) = 1
		_DistortionColorFactor("Distortion Color Factor", Range(0,1)) = .5
		_DistortionOffset("Distortion UV Offset", Vector) = (0,0,0,0)

		[PropertyGroup(_NORMALMAP, _BumpMap, _UVBumpSpeed, _BumpScale, _ApplyTexSheetUvBump)]_NormalMapEnabled("Bump", float) = 0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_UVBumpSpeed("UV Bump Speed", Vector) = (0,0,0,0)
		_BumpScale("Bump Scale", Float) = 1.0
		[ToggleOff] _ApplyTexSheetUvBump("Apply Texture Sheet Animation", float) = 1

		[PropertyGroup(SOFT_PARTICLES, softness)]_SoftParticlesEnabled("Soft Particles", float) = 0
		_Softness("Мягонькость", float) = .5
		[ToggleOff] _SubstractSoftness("Отнять мягонькость от альфы", float) = 0

		[PropertyGroup(OPACITY_FALLOFF, falloff)]_OpacityFalloffEnabled("Opacity Falloff", float) = 0
		_OpacityFalloff("Opacity Falloff", Range(0, 10)) = 1
		[Toggle(INVERT_OPACITY_FALLOFF)] _InvertOpacityFalloffEnabled("Invert Opacity Falloff", float) = 0
		[ToggleOff] _SubstractFalloff("Substract Falloff", float) = 0

		[PropertyGroup(PARTICLES_LIGHTING_ON, translucent, receiveShadows, reflections, specular, occlusion, _OverrideNormalsEnabled, _WrapDiffuseFactor, _VirtualOffsetVertexPosition)]_LightingEnabled("Lighting", float) = 0
		_WrapDiffuseFactor("Wrap Diffuse Factor (binary if Deferred)", Range(0, 1)) = .5

			[PropertyGroup(_TRANSLUCENT, _Thickness, _ThicknessSharpness, translucency)]_Translucent("Translucency", float) = 0
			_Thickness("Thickness", Range(0, 1)) = 1
			_TranslucencyColor("Translucency Color", Color) = (1,1,1,1)

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

        [ToggleOff(_RECEIVE_SHADOWS_OFF)] _ReceiveShadows("Receive Shadows", float) = 1.0
		[Toggle]_VirtualOffsetVertexPosition("Virtual Offset Vertex Position", float) = 0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[Toggle(OVERRIDE_NORMAL_ON)]_OverrideNormalsEnabled("Billboard normals (for ParticlesSysteme trails)", float) = 0

		[Toggle(FLUID_FOG)]_FluidFogEnabled("Fluid Fog", float) = 0.0
		[Toggle(WORLD_UV_XZ)]_SnapUvToWorldXZEnabled("Snap UV to World XZ", float) = 0.0
		[ToggleOff] _UseUnscaledTime("Use Unscaled Time", float) = 0.0

		[HideInInspector]_StencilRef("Stencil Ref", float) = 0
		[HideInInspector] _QueueOffset("Render Queue Offset", float) = 30

        // blend mode
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _ZTest("__zt", Float) = 3.0 // Equal for Opaque
        [HideInInspector] _CullMode("__cullMode", Float) = 2.0

		// ObsoleteProperties needs to alphatested baked GI
		[HideInInspector] _MainTex("BaseMap (RGB)", 2D) = "grey" {}
		[HideInInspector] _Color("Main Color", Color) = (1,1,1,1)

		// See ParticlesMaterialController.cs
		[HideInInspector]
		_TexSheetEnabled("texSheet", float) = 0.0
    }
    SubShader
    {
		Tags{ "RenderType" = "Opaque" "RenderPipeline" = "OwlcatPipeline" }
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
			#pragma shader_feature_local TEXTURE1_ON
			#pragma shader_feature_local RADIAL_ALPHA
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local OPACITY_FALLOFF
			#pragma shader_feature_local INVERT_OPACITY_FALLOFF
			#pragma shader_feature_local WORLD_UV_XZ
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
			#pragma shader_feature_local FLUID_FOG
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma target 4.5

            #define PASS_SCENESELECTIONPASS
			#define PARTICLES
			#define WRAP_DIFFUSE
			#define _ALPHATEST_ON
			
			#include "ParticlesGBufferPass.hlsl"

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
			#pragma shader_feature_local TEXTURE1_ON
			#pragma shader_feature_local RADIAL_ALPHA
			#pragma shader_feature_local COLOR_ALPHA_RAMP
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local OPACITY_FALLOFF
			#pragma shader_feature_local INVERT_OPACITY_FALLOFF
			#pragma shader_feature_local OVERRIDE_NORMAL_ON
			#pragma shader_feature_local WORLD_UV_XZ
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
			#pragma shader_feature_local _EMISSIONMAP
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _TRANSLUCENT
			#pragma shader_feature_local FLUID_FOG
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP

			#pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF

			#pragma shader_feature_local PARTICLES_LIGHTING_ON

			// -------------------------------------
            // Owlcat defined keywords
			#pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ DEFERRED_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma target 4.5

            #define PASS_GBUFFER
			#define PARTICLES
			#define WRAP_DIFFUSE
			#define _ALPHATEST_ON
			
			#ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "ParticlesGBufferPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Cull [_CullMode]
            ZClip On
            ZWrite Off
            ZTest [_ZTest]
            Blend[_SrcBlend][_DstBlend]
			ColorMask RGB

            Tags { "LightMode" = "ForwardLit"}
            Name "FORWARD LIT"
			HLSLPROGRAM
			#pragma only_renderers d3d11 vulkan ps4
			#pragma vertex ForwardLitVertex
			#pragma fragment ForwardLitFragment

            // -------------------------------------
            // Material Keywords
			#pragma shader_feature_local TEXTURE1_ON
			#pragma shader_feature_local RADIAL_ALPHA
			#pragma shader_feature_local COLOR_ALPHA_RAMP
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local SOFT_PARTICLES
			#pragma shader_feature_local OPACITY_FALLOFF
			#pragma shader_feature_local INVERT_OPACITY_FALLOFF
			#pragma shader_feature_local OVERRIDE_NORMAL_ON
			#pragma shader_feature_local WORLD_UV_XZ
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _EMISSIONMAP
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _TRANSLUCENT
            #pragma shader_feature_local _TRANSPARENT_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _ALPHABLENDMULTIPLY_ON

            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

			#pragma shader_feature_local PARTICLES_LIGHTING_ON
			#pragma shader_feature_local DISTORTION_ON
			#pragma shader_feature_local FLUID_FOG
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP

            // -------------------------------------
            // Unity defined keywords
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
			#define PARTICLES
			#define WRAP_DIFFUSE
			#define _ALPHATEST_ON
			#if defined(_TRANSPARENT_ON) || defined(DISTORTION_ON)
				#define SUPPORT_FOG_OF_WAR
			#endif

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "ParticlesForwardPass.hlsl"
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
			#pragma shader_feature_local TEXTURE1_ON
			#pragma shader_feature_local RADIAL_ALPHA
			#pragma shader_feature_local COLOR_ALPHA_RAMP
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local SOFT_PARTICLES
			#pragma shader_feature_local OPACITY_FALLOFF
			#pragma shader_feature_local INVERT_OPACITY_FALLOFF
			#pragma shader_feature_local OVERRIDE_NORMAL_ON
			#pragma shader_feature_local WORLD_UV_XZ
            #pragma shader_feature_local _DOUBLESIDED_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _TRANSLUCENT
            #pragma shader_feature_local _TRANSPARENT_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _ALPHABLENDMULTIPLY_ON

            #pragma shader_feature_local DISTORTION_ON
			#pragma shader_feature_local FLUID_FOG
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Owlcat defined keywords
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS

			#pragma target 4.5

			#define PASS_DISTORTION_VECTORS
			#define PARTICLES
			#define _ALPHATEST_ON

            #ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
			#include "ParticlesForwardPass.hlsl"
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
			#pragma shader_feature_local TEXTURE1_ON
			#pragma shader_feature_local RADIAL_ALPHA
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local WORLD_UV_XZ
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP

            // -------------------------------------
            // Light types
            #pragma multi_compile _ GEOMETRY_CLIP

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex Vertex
            #pragma fragment Fragment

            #define PASS_SHADOWCASTER
			#define PARTICLES
			#define _ALPHATEST_ON

            #include "ParticlesShadowCasterPass.hlsl"
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
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local WORLD_UV_XZ
            #pragma shader_feature_local VAT_ENABLED
            #pragma shader_feature_local _VAT_ROTATIONMAP

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma target 4.5

            #define PASS_DEBUG_ADDITIONAL
			#define PARTICLES
			#define _ALPHATEST_ON
			
			#include "ParticlesInput.hlsl"
			#include "../../Debugging/DebugAdditionalPass.hlsl"
			ENDHLSL
		}
    }
}
