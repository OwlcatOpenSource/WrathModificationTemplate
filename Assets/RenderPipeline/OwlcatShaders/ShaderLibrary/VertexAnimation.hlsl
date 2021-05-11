#ifndef OWLCAT_VERTEX_ANIMATION_INCLUDED
#define OWLCAT_VERTEX_ANIMATION_INCLUDED

#ifdef VERTEX_ANIMATION_ENABLED

float3 GetWind(float3 positionWS)
{
    // Global wind
    if (_GlobalWindEnabled > 0)
    {
        float strengthNoise = 0;
        int octaveIndex = 0;
        for (octaveIndex = 0; octaveIndex < WIND_STRENGTH_OCTAVES_COUNT; octaveIndex++)
        {
            float4 compressedOctave = _CompressedStrengthOctaves[octaveIndex];
            strengthNoise += (snoise(positionWS.xz * compressedOctave.y - compressedOctave.zw) + 1) * .5f * compressedOctave.x;
        }

        float strength = saturate(.5 + _StrengthNoiseContrast * (strengthNoise - .5));
        strength = lerp(1, strength, _StrengthNoiseWeight);

        float shiftNoise = 0;
        octaveIndex = 0;
        for (octaveIndex = 0; octaveIndex < WIND_SHIFT_OCTAVES_COUNT; octaveIndex++)
        {
            float4 compressedOctave = _CompressedShiftOctaves[octaveIndex];
            shiftNoise += snoise(positionWS.xz * compressedOctave.y - compressedOctave.zw) * compressedOctave.x;
        }

        float2 windVector = _WindVector;
        if (shiftNoise > 0)
        {
            float s, c;
            sincos(shiftNoise, s, c);
            float2x2 rotateMatrix = float2x2(c, -s, s,  c);
            windVector = mul(rotateMatrix, _WindVector);
        }

        windVector = windVector * strength;

        float3 windWS = float3(windVector.x, 0, windVector.y);
        float3 windOS = TransformWorldToObjectDir(windWS, false);

        return windOS;
    }

    return 0;
}

float4 SmoothCurve(float4 x)
{
    return x * x * (3.0 - 2.0 * x);
}

float4 TriangleWave(float4 x)
{
    return abs(frac(x + 0.5) * 2.0 - 1.0);
}

float4 SmoothTriangleWave(float4 x)
{
    return SmoothCurve(TriangleWave(x));
}

// Detail bending
inline float3 AnimateVertex(float3 pos, float3 normal, float4 wind, float4 animParams)
{
    // animParams stored in color
    // animParams.x = branch phase
    // animParams.y = edge flutter factor
    // animParams.z = primary factor
    // animParams.w = secondary factor

    float fDetailAmp = 0.1f;
    float fBranchAmp = 0.3f;

    // Phases (object, vertex, branch)
    float fObjPhase = dot(unity_ObjectToWorld._14_24_34, 1);
    float fBranchPhase = fObjPhase + animParams.x;

    float fVtxPhase = dot(pos.xyz, animParams.y + fBranchPhase);

    // x is used for edges; y is used for branches
    float2 vWavesIn = _Time.yy + float2(fVtxPhase, fBranchPhase );

    // 1.975, 0.793, 0.375, 0.193 are good frequencies
    float4 vWaves = (frac( vWavesIn.xxyy * float4(1.975, 0.793, 0.375, 0.193) ) * 2.0 - 1.0);

    vWaves = SmoothTriangleWave( vWaves );
    float2 vWavesSum = vWaves.xz + vWaves.yw;

    // Edge (xz) and branch bending (y)
    float3 bend = animParams.y * fDetailAmp * normal.xyz;
    bend.y = animParams.w * fBranchAmp;
    pos.xyz += ((vWavesSum.xyx * bend) + (wind.xyz * vWavesSum.y * animParams.w)) * wind.w;

    // Primary bending
    // Displace position
    //float4 objWaves = _Time.yyyy + fObjPhase;
    //float4 freq = float4(1.975, 0.793, 0.375, 0.193) * .01 * length(wind.xyz);
    //objWaves = (frac( objWaves * freq) * 2.0);
    //objWaves = SmoothTriangleWave(objWaves);
    //pos.xyz += dot(objWaves, 1) * animParams.z * wind.xyz;
    pos.xyz += animParams.z * wind.xyz;
    return pos;
}

void VertexAnimation(float4 vertexColor, float3 normalOS, inout float3 positionOS)
{
    float3 pivotWS = TransformObjectToWorld(float3(0, 0, 0));

    float4 wind = float4(GetWind(pivotWS), 1);
    wind.w = length(wind.xyz);

    //float lengthSq = dot(positionOS, positionOS);
    //float length = sqrt(lengthSq);

    ////float3 newPosOS = positionOS + wind * lengthSq * _VaWindInfluence;
    //float3 newPosOS = positionOS + wind * vertexColor.a * _VaWindInfluence;
    ////positionOS = newPosOS;
    ////return;
    //float3 newPosDir = normalize(newPosOS);
    //newPosOS = newPosDir * length;
    //positionOS = newPosOS;

    float4 animParams = float4(vertexColor.r, vertexColor.g * _VaEdgeFlutter, vertexColor.a * _VaPrimaryFactor, vertexColor.b * _VaSecondaryFactor);

    positionOS = AnimateVertex(positionOS, normalOS, wind, animParams);
}
    
#endif

#endif // OWLCAT_VERTEX_ANIMATION_INCLUDED
