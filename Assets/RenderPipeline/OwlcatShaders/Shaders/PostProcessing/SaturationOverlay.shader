Shader "Hidden/Owlcat/Render Pipeline/SaturationOverlay"
{
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			
			#include "../../ShaderLibrary/Core.hlsl"
			#include "Common.hlsl"
						
			sampler2D _MainTex;
			sampler2D _SaturationAuraRT;

			half4 Frag (Varyings input) : SV_Target
			{
				half4 color = tex2D(_MainTex, input.uv);
				half saturation = tex2D(_SaturationAuraRT, input.uv) * 2;
			 
				half3 luminance = half3(0.2126729, 0.7151522, 0.0721750);
			    half oneMinusSat = 1.0 - saturation;
			    half3 red = ( luminance.x * oneMinusSat );
			    red.r += saturation;
			    
			    half3 green = ( luminance.y * oneMinusSat );
			    green.g += saturation;
			    
			    half3 blue = ( luminance.z * oneMinusSat );
			    blue.b += saturation;
			 
				half3x3 saturationMatrix = transpose(half3x3(red,green,blue));
				color = half4(mul(saturationMatrix, color.xyz), 1);
				return color;
			}
			ENDHLSL
		}
	}
}
