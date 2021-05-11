#ifndef OWLCAT_VAT_INCLUDED
#define OWLCAT_VAT_INCLUDED

#ifdef VAT_ENABLED

    // «десь смесь из шейдеров от Houdini и keijiro https://github.com/keijiro/HdrpVatExample

    TEXTURE2D(_PosVatMap);
    TEXTURE2D(_RotVatMap);

    // Calculate a texture sample point for a given vertex.
    float2 VAT_GetSamplePoint(float2 uv, float currentFrame)
    {
        int frame = clamp(currentFrame, 0, _VatNumOfFrames - 1);
        float timeInFrames = frame / _VatNumOfFrames;
        //timeInFrames += (1 / _VatNumOfFrames);

        /*if (_VatPadPowTwo > 0)
        {
            float2 ratio = float2(_VatTextureSizeX / _VatPaddedSizeX, _VatTextureSizeY / _VatPaddedSizeY);
            uv.x = uv.x * ratio.x;
            uv.y = (1 - (timeInFrames * ratio.y)) + (1 - ((1 - uv.y) * ratio.y));
		}
        else*/
        {
            uv.y = (1 - timeInFrames) + uv.y;
		}

        return uv;
    }

    // Rotate a vector with a unit quaternion.
    float3 VAT_RotateVector(float3 v, float4 q)
    {
        return v + cross(2 * q.xyz, cross(q.xyz, v) + q.w * v);
    }

    void VAT_RigidSingle(float2 vatUv, float3 color, float currentFrame, inout float3 positionOS, inout float3 normalOS)
    {
        float2 uv = VAT_GetSamplePoint(vatUv, currentFrame);
        
        float4 positionVAT = SAMPLE_TEXTURE2D_LOD(_PosVatMap, s_linear_repeat_sampler, uv, 0);
        #ifdef _VAT_ROTATIONMAP
            float4 rotationVAT = SAMPLE_TEXTURE2D_LOD(_RotVatMap, s_linear_repeat_sampler, uv, 0);
        #else
            float4 rotationVAT = 0;
        #endif

        float3 offset = lerp(_VatPosMin, _VatPosMax, positionVAT.xyz);
        float3 pivot = lerp(_VatPivMin, _VatPivMax, color);

        rotationVAT = (rotationVAT * 2 - 1).xyzw * float4(-1, 1, 1, 1);
        
        // Output
        positionOS = VAT_RotateVector(positionOS - pivot, rotationVAT) + pivot + offset;
        normalOS = VAT_RotateVector(normalOS, rotationVAT);
	}

    void VAT_Rigid(float2 vatUv, inout float3 color, inout float3 positionOS, inout float3 normalOS)
    {
        if (_VatLerp > 0)
        {
		    float frame0 = floor(_VatCurrentFrame);
            float frame1 = ceil(_VatCurrentFrame);
            float3 pos0 = positionOS;
            float3 pos1 = positionOS;
            float3 norm0 = normalOS;
            float3 norm1 = normalOS;
            VAT_RigidSingle(vatUv, color, frame0, pos0, norm0);
            VAT_RigidSingle(vatUv, color, frame1, pos1, norm1);

            float lerpFactor = frac(_VatCurrentFrame);
            positionOS = lerp(pos0, pos1, lerpFactor);
            normalOS = normalize(lerp(norm0, norm1, lerpFactor));
        }
        else
        {
            VAT_RigidSingle(vatUv, color, _VatCurrentFrame, positionOS, normalOS);
        }

        color = 1;
	}

    void VAT_SoftSingle(float2 vatUv, float3 color, float currentFrame, inout float3 positionOS, inout float3 normalOS)
    {
        float2 uv = VAT_GetSamplePoint(vatUv, currentFrame);
        
        float4 positionVAT = SAMPLE_TEXTURE2D_LOD(_PosVatMap, s_linear_repeat_sampler, uv, 0);

        float3 offset = lerp(_VatPosMin, _VatPosMax, positionVAT.xyz);
        //offs = offs.xzy * float3(-1, 1, 1);

        //calculate normal
        #ifdef _VAT_ROTATIONMAP
            float4 normalVAT = SAMPLE_TEXTURE2D_LOD(_RotVatMap, s_linear_repeat_sampler, uv, 0);
            normalVAT.xyz *= 2;
            normalVAT.xyz -= 1;
            normalOS = normalVAT.xyz;
        #else
            //decode float to float2
            float alpha = positionVAT.w * 1024;
            // alpha = 0.8286 * 1024;
            float2 f2;
            f2.x = floor(alpha / 32.0) / 31.5;
            f2.y = (alpha - (floor(alpha / 32.0)*32.0)) / 31.5;

            //decode float2 to float3
            float3 f3;
            f2 *= 4;
            f2 -= 2;
            float f2dot = dot(f2,f2);
            f3.xy = sqrt(1 - (f2dot/4.0)) * f2;
            f3.z = 1 - (f2dot/2.0);
            f3 = clamp(f3, -1.0, 1.0);
            // f3 = f3.xzy;
            // f3.x *= -1;
            normalOS = f3;
        #endif

        // Output
        positionOS += offset;
	}

    void VAT_Soft(float2 vatUv, float3 color, inout float3 positionOS, inout float3 normalOS)
    {
        if (_VatLerp > 0)
        {
		    float frame0 = floor(_VatCurrentFrame);
            float frame1 = ceil(_VatCurrentFrame);
            float3 pos0 = positionOS;
            float3 pos1 = positionOS;
            float3 norm0 = normalOS;
            float3 norm1 = normalOS;
            VAT_SoftSingle(vatUv, color, frame0, pos0, norm0);
            VAT_SoftSingle(vatUv, color, frame1, pos1, norm1);

            float lerpFactor = frac(_VatCurrentFrame);
            positionOS = lerp(pos0, pos1, lerpFactor);
            normalOS = normalize(lerp(norm0, norm1, lerpFactor));
        }
        else
        {
            VAT_SoftSingle(vatUv, color, _VatCurrentFrame, positionOS, normalOS);
        }
	}

    void VAT_FluidSingle(float2 vatUv, float3 color, float currentFrame, inout float3 positionOS, inout float3 normalOS)
    {
        float2 uv = VAT_GetSamplePoint(vatUv, currentFrame);
        
        float4 positionVAT = SAMPLE_TEXTURE2D_LOD(_PosVatMap, s_linear_repeat_sampler, uv, 0);

        float3 offset = lerp(_VatPosMin, _VatPosMax, positionVAT.xyz);
        //offs = offs.xzy * float3(-1, 1, 1);

        //calculate normal
        #ifdef _VAT_ROTATIONMAP
            float4 normalVAT = SAMPLE_TEXTURE2D_LOD(_RotVatMap, s_linear_repeat_sampler, uv, 0);
            normalVAT.xyz *= 2;
            normalVAT.xyz -= 1;
            normalOS = normalVAT.xyz;
        #else
            //decode float to float2
            float alpha = positionVAT.w * 1024;
            // alpha = 0.8286 * 1024;
            float2 f2;
            f2.x = floor(alpha / 32.0) / 31.5;
            f2.y = (alpha - (floor(alpha / 32.0)*32.0)) / 31.5;

            //decode float2 to float3
            float3 f3;
            f2 *= 4;
            f2 -= 2;
            float f2dot = dot(f2,f2);
            f3.xy = sqrt(1 - (f2dot/4.0)) * f2;
            f3.z = 1 - (f2dot/2.0);
            f3 = clamp(f3, -1.0, 1.0);
            // f3 = f3.xzy;
            // f3.x *= -1;
            normalOS = f3;
        #endif

        // Output
        positionOS = offset;
	}

    void VAT_Fluid(float2 vatUv, float3 color, inout float3 positionOS, inout float3 normalOS)
    {
        if (_VatLerp > 0)
        {
		    float frame0 = floor(_VatCurrentFrame);
            float frame1 = ceil(_VatCurrentFrame);
            float3 pos0 = positionOS;
            float3 pos1 = positionOS;
            float3 norm0 = normalOS;
            float3 norm1 = normalOS;
            VAT_FluidSingle(vatUv, color, frame0, pos0, norm0);
            VAT_FluidSingle(vatUv, color, frame1, pos1, norm1);

            float lerpFactor = frac(_VatCurrentFrame);
            positionOS = lerp(pos0, pos1, lerpFactor);
            normalOS = normalize(lerp(norm0, norm1, lerpFactor));
        }
        else
        {
            VAT_FluidSingle(vatUv, color, _VatCurrentFrame, positionOS, normalOS);
        }
	}

    void VAT(float2 vatUv, inout float3 color, inout float3 positionOS, inout float3 normalOS)
    {
        switch(_VatType)
        {
            case 0: VAT_Rigid(vatUv, color, positionOS, normalOS); break;
            case 1: VAT_Soft(vatUv, color, positionOS, normalOS); break;
            case 2: VAT_Fluid(vatUv, color, positionOS, normalOS); break;
		}
	}
#endif

#endif // OWLCAT_VAT_INCLUDED
