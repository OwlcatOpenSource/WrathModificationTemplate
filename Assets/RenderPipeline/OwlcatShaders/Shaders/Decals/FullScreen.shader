Shader "Owlcat/Decals/FullScreen"
{
    Properties
    {
		[Enum(Local, 0, World, 1, LocalRadial, 2, WorldRadial, 3)] _UvMapping("UV Mapping", float) = 0

        // альбедо не всегда нужен
        _BaseMap ("Texture", 2D) = "white" {}
		_UV0Speed("UV0 Speed", Vector) = (0,0,0,0)
		_BaseColor("Color", Color) = (1,1,1,1)

		_HdrColorScale("HDR Color Scale", float) = 1.0
		_AlphaScale("Alpha Scale", float) = 1
		_Cutoff("Cutout", Range(0, 1)) = .001
		[ToggleOff] _SubstractAlphaFlag("Substract Color Alpha", float) = 0

		[TextureKeyword(_NORMALMAP)]
        [NoScaleOffset]
        _BumpMap("Normal Map", 2D) = "bump" {}

        [TextureKeyword(_MASKSMAP)]
        [NoScaleOffset]
        _MasksMap("Masks (R - Roughness G - Emission B - Metallic A - Translucency)", 2D) = "black" {}

        _Roughness("Roughness", Range(0, 1)) = 1
        _Metallic("Metallic", Range(0, 1)) = 0

		[PropertyGroup(TEXTURE1_ON, tex1, uv1)]_Tex1Enabled("Texture1", float) = 0
		_MainTex1("Texture", 2D) = "white" {}
		_UV1Speed("UV1 Speed", Vector) = (0,0,0,0)
		_MainTex1Weight("Main Tex 1 Weight", float) = 1.0
		[Enum(Lerp RGBA,1,Lerp RGB Multiply A,2)] _Tex1MixMode("Mix Mode", float) = 1.0

		[PropertyGroup(NOISE0_ON, noise0, uvCorrection, noiseOffset)]_Noise0Enabled("Noise 0", float) = 0
		_Noise0Tex("Noise 0", 2D) = "black" {}
		_Noise0Scale("Noise 0 Scale", float) = 0.0
		_Noise0Speed("Noise 0 Speed", Vector) = (0,0,0,0)
		[Toggle(NOISE_UV_CORRECTION)]_NoiseUvCorrectionEnabled("Noise UV Correction", float) = 0

		[PropertyGroup(NOISE1_ON, noise1, uvCorrection, noiseOffset)]_Noise1Enabled("Noise 1", float) = 0
		_Noise1Tex("Noise 1", 2D) = "black" {}
		_Noise1Scale("Noise 1 Scale", float) = 0.0
		_Noise1Speed("Noise 1 Speed", Vector) = (0,0,0,0)

        [PropertyGroup(_SLOPE_FADE, slope)]_SlopeFade("Slope Fade Enabled", float) = 0
        _DecalSlopeFadeStart("Slope Fade Start", Range(0, 1)) = 1
		_DecalSlopeFadePower("Slope Fade Power", float) = 1

        [PropertyGroup(_EMISSION, emission)]_EmissionEnabled("Emission Enabled", float) = 0
		[TextureKeyword(_EMISSIONMAP)]_EmissionMap("Emission Map", 2D) = "white" {}
		[Enum(Use Emission Map RGB, 0, Use Emission Map R Channel Multiply Albedo RGB, 1)]_DecalEmissionMapUsage("Emission Map Usage", float) = 1
		_EmissionUVSpeed("Emission UV Speed", Vector) = (0,0,0,0)
        _DecalEmissionIntensity("Intensity", float) = 1
		_DecalEmissionColor("Color", Color) = (1,1,1,1)
		[Toggle]_DecalEmissionUseColorFactor("Use Color Factor", float) = 0
		_EmissionColorFactor("Emission Color Factor", Range(0, 1)) = 1

        [PropertyGroup(_GRADIENT_FADE, gradient)]_GradientFade("Gradient Fade Enabled", float) = 0
        [Enum(MaxOpacityTop,0,MaxOpacityMiddle,1,MaxOpacityBottom,2)] _DecalGradientMode("Gradient Mode", float) = 0
		[Toggle]_DecalExpGradient("Exp Gradient", float) = 0

		[PropertyGroup(COLOR_ALPHA_RAMP, ramp)]_ColorAlphaRampEnabled("Color Alpha Ramp Enabled", float) = 0
		_ColorAlphaRamp("Color Alpha Ramp", 2D) = "white" {}
		_RampScrollSpeed("Ramp Scroll Speed", float) = 0
		_RampAlbedoWeight("Ramp -> Albedo x Ramp Lerp", Range(0, 1)) = 0

		[ToggleOff(_RECEIVE_SHADOWS_OFF)] _ReceiveShadows("Receive Shadows", float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="OwlcatPipeline" }
        LOD 100

        Pass
        {
            Name "FULL SCREEN DECAL"
            Tags { "LightMode" = "FullScreenDecal"}

            // back faces with zfail, for cases when camera is inside the decal volume
			Cull Off
			ZWrite Off
			ZTest Always
			Blend SrcAlpha OneMinusSrcAlpha

			Stencil
			{
				Ref 1 // see StencilRef
				ReadMask 1
				Comp equal
			}

            HLSLPROGRAM
            #pragma target 4.5
            #pragma only_renderers d3d11 ps4 xboxone vulkan metal
            #pragma vertex DecalVertex
            #pragma fragment DecalFragment

            //--------------------------------------
            // Material keywords
            #pragma shader_feature_local _SLOPE_FADE
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKSMAP
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _GRADIENT_FADE
			#pragma shader_feature_local TEXTURE1_ON
			#pragma shader_feature_local NOISE0_ON
			#pragma shader_feature_local NOISE1_ON
			#pragma shader_feature_local NOISE_UV_CORRECTION
			#pragma shader_feature_local COLOR_ALPHA_RAMP

			// -------------------------------------
            // Unity defined keywords
			#pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
			
			#pragma multi_compile_fog

			// -------------------------------------
            // Owlcat defined keywords
			#pragma multi_compile _ DEFERRED_ON
			#pragma multi_compile _ SHADOWS_HARD SHADOWS_SOFT
			#pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS

            #define FULL_SCREEN_DECALS
			#define DECALS_LIGHTING_ON

			// хардкод, чтобы работали тени от shadowmask
			#define SHADOWS_SHADOWMASK
			#define LIGHTMAP_ON

			#ifdef DEBUG_DISPLAY
                #include "../../Debugging/DebugInput.hlsl"
            #endif
            
            #include "DecalPass.hlsl"
            ENDHLSL
        }
    }
}
