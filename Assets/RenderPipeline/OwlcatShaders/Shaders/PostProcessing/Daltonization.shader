Shader "Hidden/Owlcat Render Pipeline/Daltonization"
{
    Properties
    {
        _MainTex("Source", 2D) = "white" {}
    }

    HLSLINCLUDE

        #pragma multi_compile_local _ _USE_RGBM

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
        #include "../../ShaderLibrary/Core.hlsl"
        #include "Common.hlsl"

        TEXTURE2D_X(_BlitTex);

        float4 _BlitTex_TexelSize;

        float4 _Params; // x: Intensity, y: Type

        #define Intensity _Params.x
        #define Type _Params.y

        #define Protanopia (1)
        #define Deuteranopia (2)
        #define Tritanopia (3)
        #define DullYellow (4)
        #define VibrantBluishPurple (5)
        #define DarkBlue (6)
        #define DarkBlue2 (7)

        float3 Daltonize(float3 color, uint daltonizationType, float strength)
        {
            if (daltonizationType < 1 || daltonizationType > 8)
            {
                return color;
            }

            switch (daltonizationType)
            {
                case 1: // Protanopia
                case 2: // Deuteranopia
                case 3: // Tritanopia
                {
                    strength = clamp(strength, 0.0f, 1.0f);

                    float3x3 RgbToLms = { { 17.8824f, 43.5161f, 4.1193f },
                                            { 3.4557f,  27.1554f, 3.8671f },
                                            { 0.02996f, 0.18431f, 1.4670f } };

                    float3x3 LmsToRgb = { { 0.0809f,  -0.1305f,  0.1167f },
                                            { -0.0102f,  0.0540f, -0.1136f },
                                            { -0.0003f, -0.0041f,  0.6935f } };

                    // reds are greatly reduced
                    float3x3 protanopia = { { 1.0f - strength, 2.02344f*strength, -2.52581f*strength },
                                            { 0.0f,          1.0f,               0.0f },
                                            { 0.0f,          0.0f,               1.0f } };

                    // greens are greatly reduced
                    float3x3 deuteranopia = { { 1.0f,             0.0f,          0.0f },
                                              { 0.4942f*strength, 1.0f - strength, 1.24827f*strength },
                                              { 0.0f,             0.0f,          1.0f } };

                    // blues are greatly reduced
                    float3x3 tritanopia = { { 1.0f,                0.0f,               0.0f },
                                            { 0.0f,                1.0f,               0.0f },
                                            { -0.012245f*strength, 0.072035f*strength, 1.0f - strength } };


                    float3x3 correctionType1 = { { 0.0f, 0.0f, 0.0f },
                                                 { 0.7f, 1.0f, 0.0f },
                                                 { 0.7f, 0.0f, 1.0f } };

                    float3x3 correctionType2 = { { 1.0f, 0.7f, 0.0f },
                                                 { 0.0f, 0.0f, 0.0f },
                                                 { 0.0f, 0.7f, 1.0f } };


                    float3x3 correctionType3 = { { 1.0f, 0.0f, 0.7f },
                                                 { 0.7f, 0.7f, 0.0f },
                                                 { 0.7f, 0.0f, 0.0f } };

                    float3 colorIn = color;
                    float3x3 correction;
                    float3x3 defect;
                    if (daltonizationType == 1)
                    {
                        defect = protanopia;
                        correction = correctionType1;

                        if (colorIn.r > 0.5f && (colorIn.g + colorIn.b) < 0.5f)
                        {
                            colorIn.g = clamp(colorIn.g + 0.2f, 0.0f, 1.0f);
                            colorIn.b = clamp(colorIn.b + 0.2f, 0.0f, 1.0f);
                        }
                    }
                    else if (daltonizationType == 2)
                    {
                        defect = deuteranopia;
                        correction = correctionType1;

                        if (colorIn.r > (2.0f * colorIn.g) && (colorIn.r + colorIn.g) > colorIn.b)
                        {
                            colorIn.b = clamp(colorIn.b + 0.3f, 0.0f, 1.0f);
                        }
                    }
                    else //if (daltonizationType == 3)
                    {
                        defect = tritanopia;
                        correction = correctionType3;
                    }

                    float3 originalLms = mul(RgbToLms, color);
                    float3 simulatedLms = mul(defect, originalLms);
                    float3 simulatedRgb = mul(LmsToRgb, simulatedLms);
                    float3 error = color - simulatedRgb;
                    float3 rgbCorrection = mul(correction, error);

                    color = colorIn + rgbCorrection;
                }
                break;

                case 4: // BrightYellow
                {
                    if ((color.r > 0.25f) && (color.g < 0.27f) && (color.b < 0.27f))
                    {
                        color.r = clamp(color.r + 0.2f, 0.0f, 1.0f);
                        color.g = color.r;
                        color.b = color.b * 0.25f;
                    }
                }
                break;

                case 5: // DullYellow
                {
                    if ((color.r > 0.25f) && (color.g < 0.27f) && (color.b < 0.27f))
                    {
                        color.g = color.r;
                        color.b = color.b * 0.25f;
                    }
                }
                break;

                case 6: // VibrantBluishPurple
                {
                    if ((color.r > 0.25f) && (color.g < 0.27f) && (color.b < 0.27f))
                    {
                        color.r = 0.404 + color.r * 0.1f; // 0.404 == (103.0f / 255.0f)
                        color.g = 0.263 + color.g * 0.1f; // 0.263 == (67.0f / 255.0f)
                        color.b = clamp(0.906 + color.b * 0.1f, 0.0f, 1.0f); // 0.906 == (231.0f / 255.0f)
                    }
                }
                break;

                case 7: // DarkBlue
                {
                    if ((color.r < 0.35f) && (color.g > 0.35f) && (color.b > 0.35f))
                    {
                        color.r = color.r * 0.15f;
                        color.g = color.g * 0.15f;
                        color.b = 0.215f;
                    }
                }
                break;

                case 8: // DarkBlue2
                {
                    if ((color.r > 0.25f) && (color.g < 0.27f) && (color.b < 0.27f))
                    {
                        color.r = color.r * 0.15f;
                        color.g = color.g * 0.15f;
                        color.b = 0.215f;
                    }
                }
                break;
            }

            return color;
        }

        half4 Daltonization(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            half4 color = SAMPLE_TEXTURE2D_X(_BlitTex, sampler_LinearClamp, input.uv);

            color.rgb = Daltonize(color.rgb, (uint)Type, Intensity);

            return color;
        }
    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "Daltonization"

            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment Daltonization
            ENDHLSL
        }
    }
}
