Shader "Hidden/Owlcat/Terrain/CloneBrush"
{
    Properties
    {
        _MainTex ("Texture", any) = "" {}
    }

    SubShader
    {

        ZTest Always Cull Off ZWrite Off

        CGINCLUDE

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;      // 1/width, 1/height, width, height
            float4 _LayerMask;

            sampler2D _BrushTex;

            float4 _BrushParams;
            #define BRUSH_STRENGTH      (_BrushParams[0])
            #define BRUSH_TARGETHEIGHT  (_BrushParams[1])
            #define BRUSH_STAMPHEIGHT   (_BrushParams[2])
            #define BRUSH_ROTATION      (_BrushParams[3])

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            float3 RotateUVs(float2 sourceUV, float rotAngle)
            {
                float4 rotAxes;
                rotAxes.x = cos(rotAngle);
                rotAxes.y = sin(rotAngle);
                rotAxes.w = rotAxes.x;
                rotAxes.z = -rotAxes.y;

                float2 tempUV = sourceUV - float2(0.5, 0.5);
                float3 retVal;

                // We fix some flaws by setting zero-value to out of range UVs, so what we do here
                // is test if we're out of range and store the mask in the third component.
                retVal.xy = float2(dot(rotAxes.xy, tempUV), dot(rotAxes.zw, tempUV)) + float2(0.5, 0.5);
                tempUV = clamp(retVal.xy, float2(0.0, 0.0), float2(1.0, 1.0));
                retVal.z = ((tempUV.x == retVal.x) && (tempUV.y == retVal.y)) ? 1.0 : 0.0;
                return retVal;
            }

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                return o;
            }

            float SmoothApply(float height, float brushStrength, float targetHeight)
            {
                if (targetHeight > height)
                {
                    height += brushStrength;
                    height = height < targetHeight ? height : targetHeight;
                }
                else
                {
                    height -= brushStrength;
                    height = height > targetHeight ? height : targetHeight;
                }
                return height;
            }

            float ApplyBrush(float height, float brushStrength)
            {
                return SmoothApply(height, brushStrength, BRUSH_TARGETHEIGHT);
            }

        ENDCG


        Pass    // 0 clone stamp tool (alphaMap)
        {
            Name "Clone Stamp Tool Alphamap"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment CloneAlphamap

            sampler2D _CloneTex;
            float _IsEmptyLayer;

            float4 CloneAlphamap(v2f i) : SV_Target
            {
                float4 sampleAlpha = tex2D(_CloneTex, i.texcoord);
                sampleAlpha.r *= 1 - _IsEmptyLayer;
                return sampleAlpha;
            }
            ENDCG
        }

        Pass    // 1 clone stamp tool (heightmap)
        {
            Name "Clone Stamp Tool Heightmap"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment CloneHeightmap

            sampler2D _CloneTex;

            #define HeightOffset     (_BrushParams[1])
            #define TerrainMaxHeight (_BrushParams[2])

            float4 CloneHeightmap(v2f i) : SV_Target
            {
                float3 sampleUV = RotateUVs(i.texcoord, BRUSH_ROTATION);

                float currentHeight = UnpackHeightmap(tex2D(_MainTex, i.texcoord));
                float sampleHeight = UnpackHeightmap(tex2D(_CloneTex, i.texcoord)) + (HeightOffset / TerrainMaxHeight);

                // * 0.5f since strength in this is far more potent than other tools since its not smoothly applied to a target
                float brushShape = BRUSH_STRENGTH * 0.5f * sampleUV.z * UnpackHeightmap(tex2D(_BrushTex, i.texcoord));

                return PackHeightmap(clamp(lerp(currentHeight, sampleHeight, brushShape), 0.0f, 0.5f));
            }
            ENDCG
        }

        Pass    // 2 Copy the R channel of the input into a specific channel in the output
        {
            Name "Set Terrain Layer Channel"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment SetLayer

            sampler2D _AlphaMapTexture;
            sampler2D _OldAlphaMapTexture;

            sampler2D _OriginalTargetAlphaMap;
            float4 _OriginalTargetAlphaMask;

            #define BRUSH_STRENGTH      (_BrushParams[0])
            #define BRUSH_TARGETHEIGHT  (_BrushParams[1])
            #define BRUSH_STAMPHEIGHT   (_BrushParams[2])
            #define BRUSH_ROTATION      (_BrushParams[3])

            struct appdata {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
            };


            struct Varyings {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
            };

            Varyings vert(appdata v)
            {
                Varyings o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                o.texcoord2 = v.texcoord2;
                return o;
            }

            float4 SetLayer(Varyings i) : SV_Target
            {
                // alpha map we are modifying -- _LayerMask tells us which channel is the target (set to 1.0), non-targets are 0.0
                // Note: all four channels can be non-targets, as the target may be in a different alpha map texture
                float4 alphaMap = tex2D(_AlphaMapTexture, i.texcoord2);

                // old alpha of the target channel (according to the current terrain tile)
                float4 origTargetAlphaMapSample = tex2D(_OriginalTargetAlphaMap, i.texcoord2);
                float origTargetAlpha = dot(origTargetAlphaMapSample, _OriginalTargetAlphaMask);

                // new alpha of the target channel (according to PaintContext destRenderTexture)
                float2 newAlpha = tex2D(_MainTex, i.texcoord).rg;

                float brushShape = BRUSH_STRENGTH * UnpackHeightmap(tex2D(_BrushTex, i.texcoord)) * newAlpha.g;
                return lerp(alphaMap, _LayerMask * newAlpha.r + (1 - _LayerMask) * alphaMap, brushShape);
            }
            ENDCG
        }

        Pass    // 3 - Select one channel and copy it into R channel
        {
            Name "Get Terrain Layer Channel"

            BlendOp Max

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment GetLayer

            float4 GetLayer(v2f i) : SV_Target
            {
                float4 layerWeights = tex2D(_MainTex, i.texcoord);
                float mask = (i.texcoord.x >= 0 && i.texcoord.x <= 1 && i.texcoord.y >= 0 && i.texcoord.y <= 1);
                return float4(dot(layerWeights, _LayerMask), mask, 0, 0);
            }
            ENDCG
        }
    }
    Fallback Off
}
