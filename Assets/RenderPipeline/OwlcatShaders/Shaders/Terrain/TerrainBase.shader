Shader "Hidden/Owlcat/TerrainBase"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo(RGB), Smoothness(A)", 2D) = "white" {}
        _MetallicTex ("Metallic (R)", 2D) = "black" {}

		[ToggleOff(_RECEIVE_SHADOWS_OFF)] _ReceiveShadows("Receive Shadows", float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
    }

    SubShader
    {
        Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" "RenderPipeline" = "OwlcatPipeline" "IgnoreProjector" = "False"}

        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "GBuffer"}
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #define PASS_GBUFFER

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature _NORMALMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #pragma shader_feature _DECALS
            #define TERRAIN_SPLAT_BASEPASS 1

            #include "TerrainInput.hlsl"
            #include "TerrainGBufferPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "ForwardLit"}
            HLSLPROGRAM
			#pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #define PASS_FORWARD_LIT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ SHADOWS_HARD SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature _NORMALMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature _TERRAIN_INSTANCED_PERPIXEL_NORMAL
			#pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF
            #define TERRAIN_SPLAT_BASEPASS 1

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
            #pragma multi_compile __ GEOMETRY_CLIP

            #include "TerrainInput.hlsl"
            #include "TerrainShadowCasterPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "META"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex OwlcatVertexMeta
            #pragma fragment OwlcatFragmentMeta

            #pragma shader_feature EDITOR_VISUALIZATION

            #define PASS_META

            #include "TerrainInput.hlsl"
            #include "TerrainMetaPass.hlsl"

            ENDHLSL
        }

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }
}
