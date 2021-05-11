Shader "Hidden/Owlcat/Render Pipeline/RadialBlur"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_RadialBlurStrength("", Float) = 0.5
		_RadialBlurWidth("", Float) = 0.5
		_RadialBlurCenter("", Vector) = (0,0,0,0)
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
			half4 _MainTex_TexelSize;
			half2 _RadialBlurCenter;
			half _RadialBlurStrength;
			half _RadialBlurWidth;

			half4 frag (v2f i) : SV_Target
			{
				half4 color = tex2D(_MainTex, i.uv);

				// some sample positions
				half samples[10];
				samples[0] = -0.08;
				samples[1] = -0.05;
				samples[2] = -0.03;
				samples[3] = -0.02;
				samples[4] = -0.01;
				samples[5] = 0.01;
				samples[6] = 0.02;
				samples[7] = 0.03;
				samples[8] = 0.05;
				samples[9] = 0.08;

				// direction to the center
				half2 dir = _RadialBlurCenter - i.uv;

				// distance to center
				half dist = length(dir);

				// normalize direction
				dir = dir / dist;

				// addition samples toward center
				half4 sum = color;
				for (int n = 0; n < 10; n++)
				{
					sum += tex2D(_MainTex, i.uv + dir * samples[n] * _RadialBlurWidth);
				}

				// eleven samples
				sum *= 1.0 / 11.0;

				half alpha = saturate(dist * _RadialBlurStrength);

				color.rgb = lerp(color.rgb, sum.rgb, alpha);
				color.a = alpha;

				return color;
			}
			ENDCG
		}
	}
}
