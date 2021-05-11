Shader "Hidden/Owlcat/TerrainTools"
{
    Properties
    {
        _MainTex ("Texture", any) = "" {}
        _Heightmap("Heightmap", any) = "" {}
    }

    SubShader
    {
        ZTest Always Cull Off ZWrite Off

        CGINCLUDE

            #include "UnityCG.cginc"
            #include "TerrainTool.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;      // 1/width, 1/height, width, height

            sampler2D _BrushTex;

            float4 _BrushParams;
            #define BRUSH_STRENGTH      (_BrushParams[0])
            #define BRUSH_TARGETHEIGHT  (_BrushParams[1])
            #define BRUSH_STAMPHEIGHT   (_BrushParams[2])

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 pcUV : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 pcUV : TEXCOORD0;
            };

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.pcUV = v.pcUV;
                return o;
            }

            float ApplyBrush(float height, float brushStrength)
            {
                float targetHeight = BRUSH_TARGETHEIGHT;
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

        ENDCG

        Pass    // 0 paint splat alphamap
        {
            Name "Paint Texture"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment PaintSplatAlphamap

            float2 _SlopeTreshold;
            sampler2D _Normalmap;
            float4 _Normalmap_TexelSize;

            float4 PaintSplatAlphamap(v2f i) : SV_Target
            {
                float2 brushUV = PaintContextUVToBrushUV(i.pcUV);
                float2 heightmapUV = PaintContextUVToHeightmapUV(i.pcUV) + _Normalmap_TexelSize.xy * 0.5;

                float3 normal = tex2Dlod(_Normalmap, float4(heightmapUV, 0, 0)) * 2 - 1;

                float slope = dot(normal, float3(0, 1, 0));
                float slopeFactor = 0;
                if (slope > _SlopeTreshold.x && slope <= _SlopeTreshold.y)
                {
                    slopeFactor = 1;
                }

                // out of bounds multiplier
                float oob = all(saturate(brushUV) == brushUV) ? 1.0f : 0.0f;

                float brushStrength = BRUSH_STRENGTH * oob * slopeFactor * UnpackHeightmap(tex2D(_BrushTex, brushUV));
                float alphaMap = tex2D(_MainTex, i.pcUV).r;
                return ApplyBrush(alphaMap, brushStrength);
            }

            ENDCG
        }
    }
}
