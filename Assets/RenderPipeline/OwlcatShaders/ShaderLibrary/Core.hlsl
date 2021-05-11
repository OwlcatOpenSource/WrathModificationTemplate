#ifndef OWLCAT_PIPELINE_CORE_INCLUDED
#define OWLCAT_PIPELINE_CORE_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
//#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Version.hlsl"
#include "Input.hlsl"

// API dependent semantics
#ifdef SHADER_API_PSSL
    #define CLIP_DISTANCE_SEMANTIC0 S_CLIP_DISTANCE0
#else
    #define CLIP_DISTANCE_SEMANTIC0 SV_ClipDistance0
#endif

#if !defined(SHADER_HINT_NICE_QUALITY)
    //#ifdef SHADER_API_MOBILE
        //#define SHADER_HINT_NICE_QUALITY 0
    //#else
        #define SHADER_HINT_NICE_QUALITY 1
    //#endif
#endif

// Shader Quality Tiers in LWRP. 
// SRP doesn't use Graphics Settings Quality Tiers.
// We should expose shader quality tiers in the pipeline asset.
// Meanwhile, it's forced to be:
// High Quality: Non-mobile platforms or shader explicit defined SHADER_HINT_NICE_QUALITY
// Medium: Mobile aside from GLES2
// Low: GLES2 
#if SHADER_HINT_NICE_QUALITY
    #define SHADER_QUALITY_HIGH
#elif defined(SHADER_API_GLES)
    #define SHADER_QUALITY_LOW
#else
    #define SHADER_QUALITY_MEDIUM
#endif

#ifndef BUMP_SCALE_NOT_SUPPORTED
    #define BUMP_SCALE_NOT_SUPPORTED !SHADER_HINT_NICE_QUALITY
#endif

struct VertexPositionInputs
{
    float3 positionWS; // World space position
    float3 positionVS; // View space position
    float4 positionCS; // Homogeneous clip space position
    float4 positionNDC; // Homogeneous normalized device coordinates
};

struct VertexNormalInputs
{
    real3 tangentWS;
    real3 bitangentWS;
    float3 normalWS;
};

VertexPositionInputs GetVertexPositionInputs(float3 positionOS)
{
    VertexPositionInputs input;
    input.positionWS = TransformObjectToWorld(positionOS);
    input.positionVS = TransformWorldToView(input.positionWS);
    input.positionCS = TransformWorldToHClip(input.positionWS);

	#if defined(PARTICLES)
		float2 offsetPos = input.positionCS.zw + float2(UNITY_MATRIX_P[2][2], UNITY_MATRIX_P[3][2]) * _VirtualOffset;
		input.positionCS.z = (offsetPos.x / offsetPos.y) * input.positionCS.w;
	#endif
    
    float4 ndc = input.positionCS * 0.5f;
    input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
    input.positionNDC.zw = input.positionCS.zw;
        
    return input;
}

VertexNormalInputs GetVertexNormalInputs(float3 normalOS)
{
    VertexNormalInputs tbn;
    tbn.tangentWS = real3(1.0, 0.0, 0.0);
    tbn.bitangentWS = real3(0.0, 1.0, 0.0);
    tbn.normalWS = TransformObjectToWorldNormal(normalOS);
    return tbn;
}

VertexNormalInputs GetVertexNormalInputs(float3 normalOS, float4 tangentOS)
{
    VertexNormalInputs tbn;

    // mikkts space compliant. only normalize when extracting normal at frag.
    real sign = tangentOS.w * GetOddNegativeScale();
    tbn.normalWS = TransformObjectToWorldNormal(normalOS);
    tbn.tangentWS = TransformObjectToWorldDir(tangentOS.xyz);
    tbn.bitangentWS = cross(tbn.normalWS, tbn.tangentWS) * sign;
    return tbn;
}

// Returns 'true' if the current view performs a perspective projection.
bool IsPerspectiveProjection()
{
    return (unity_OrthoParams.w == 0);
}

float3 GetCameraPositionWS()
{
    // Currently we do not support Camera Relative Rendering so
    // we simply return the _WorldSpaceCameraPos until then
    return _WorldSpaceCameraPos;

    // We will replace the code above with this one once
    // we start supporting Camera Relative Rendering
    //#if (SHADEROPTIONS_CAMERA_RELATIVE_RENDERING != 0)
    //    return float3(0, 0, 0);
    //#else
    //    return _WorldSpaceCameraPos;
    //#endif
}

// Could be e.g. the position of a primary camera or a shadow-casting light.
float3 GetCurrentViewPosition()
{
    // Currently we do not support Camera Relative Rendering so
    // we simply return the _WorldSpaceCameraPos until then
    return GetCameraPositionWS();

    // We will replace the code above with this one once
    // we start supporting Camera Relative Rendering
    //#if defined(SHADERPASS) && (SHADERPASS != SHADERPASS_SHADOWS)
    //    return GetCameraPositionWS();
    //#else
    //    // This is a generic solution.
    //    // However, for the primary camera, using '_WorldSpaceCameraPos' is better for cache locality,
    //    // and in case we enable camera-relative rendering, we can statically set the position is 0.
    //    return UNITY_MATRIX_I_V._14_24_34;
    //#endif
}

// Returns the forward (central) direction of the current view in the world space.
float3 GetViewForwardDir()
{
    float4x4 viewMat = GetWorldToViewMatrix();
    return -viewMat[2].xyz;
}

float3 GetWorldSpaceNormalizeViewDir(float3 positionWS)
{
    if (IsPerspectiveProjection())
    {
        // Perspective
        float3 V = GetCurrentViewPosition() - positionWS;
        return normalize(V);
    }
    else
    {
        // Orthographic
        return -GetViewForwardDir();
    }
}

float SampleDepthTexture(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_CameraDepthRT, s_point_clamp_sampler, uv.xy * _DepthPyramidSamplingRatio, 0).x;
}

float4 GatherDepthTexture(float2 uv)
{
    return GATHER_TEXTURE2D(_CameraDepthRT, s_point_clamp_sampler, uv.xy * _DepthPyramidSamplingRatio);
}

struct DepthGradients
{
    float Depth;
    float4 Dx;
    float4 Dy;
};

// написано по статье http://www.humus.name/index.php?page=3D&ID=84
// модифицировано по статье https://www.slideshare.net/philiphammer/dissecting-the-rendering-of-the-surge
// во второй ссылке неправильный паттерн семлирования (см. http://wojtsterna.blogspot.com/2018/02/directx-11-hlsl-gatherred.html)
// Sample 2 quads
//		+------+------+
//		|      |      |
//		| d0.w | d0.z |
//		+------+------+------+
//		|      | d0.y |      |
//		| d0.x | d1.w | d1.z |
//		+------+------+------+
//		       |      |      |
//			   | d1.x | d1.y |
//			   +------+------+
DepthGradients GetDepthGradients(float2 positionCS)
{
    DepthGradients result = (DepthGradients)0;
    float4 screenUv = (positionCS.xyxy + float4(-1, -1, 0, 0)) * _ScreenSize.zwzw;
    const float4 d0 = GatherDepthTexture(screenUv.xy);
	const float4 d1 = GatherDepthTexture(screenUv.zw);

	result.Depth = d1.w;
	float dx0 = d0.x;
	float dx1 = d1.z;
	float dy0 = d0.z;
	float dy1 = d1.x;

	// Find suitable neighbor screen positions in x and y so we can compute proper gradients
	// Select based on the smallest different in depth
	float absDx0 = abs(dx0 - result.Depth);
	float absDx1 = abs(dx1 - result.Depth);
	float absDy0 = abs(dy0 - result.Depth);
	float absDy1 = abs(dy1 - result.Depth);
	float minDx, minDy;

    // выбираем пиксель с меньшим перепадом глубины по оси X
    if (absDx0 < absDx1)
	{
        result.Dx = float4(positionCS.xy + float2(-1.0f, 0.0f), dx0, 1);
		minDx = absDx0;
	}
    else
	{
        result.Dx = float4(positionCS.xy + float2(1.0f, 0.0f), dx1, -1);
		minDx = absDx1;
	}

    // если перепад глубины между соседними (НЕ центральным) пикселями меньше выбранного
    // это значит что центральный пиксель окружен с обеих сторон большими перепадам,
    // значит соседние пиксели нельзя использовать для градиента, поэтому оставляем центральный
	if (abs(dx0 - dx1) < minDx)
	{
		result.Dx.z = result.Depth;
	}

    // выбираем пиксель с меньшим перепадом глубины по оси Y
    if (absDy0 < absDy1)
	{
        result.Dy = float4(positionCS.xy + float2(0.0f, -1.0f), dy0, 1);
		minDy = absDy0;
	}
    else
	{
        result.Dy = float4(positionCS.xy + float2(0.0f, 1.0f), dy1, -1);
		minDy = absDy1;
	}

    // если перепад глубины между соседними (НЕ центральным) пикселями меньше выбранного
    // это значит что центральный пиксель окружен с обеих сторон большими перепадам,
    // значит соседние пиксели нельзя использовать для градиента, поэтому оставляем центральный
	if (abs(dy0 - dy1) < minDy)
	{
		result.Dy.z = result.Depth;
	}

    return result;
}

#if UNITY_REVERSED_Z
    #if SHADER_API_OPENGL || SHADER_API_GLES || SHADER_API_GLES3
        //GL with reversed z => z clip range is [near, -far] -> should remap in theory but dont do it in practice to save some perf (range is close enough)
        #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(-(coord), 0)
    #else
        //D3d with reversed Z => z clip range is [near, 0] -> remapping to [0, far]
        //max is required to protect ourselves from near plane not being correct/meaningfull in case of oblique matrices.
        #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(((1.0-(coord)/_ProjectionParams.y)*_ProjectionParams.z),0)
    #endif
#elif UNITY_UV_STARTS_AT_TOP
    //D3d without reversed z => z clip range is [0, far] -> nothing to do
    #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
#else
    //Opengl => z clip range is [-near, far] -> should remap in theory but dont do it in practice to save some perf (range is close enough)
    #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
#endif

#if defined(_DOUBLESIDED_ON)
    #if (defined(_NORMALMAP) && !defined(PARTICLES)) || (defined(PARTICLES) && defined(_NORMALMAP) && defined(PARTICLES_LIGHTING_ON))
        #define FLIP_DOUBLESIDED(IN, FACE) float4 flipSign = IS_FRONT_VFACE(FACE, true, false) ? 1.0 : _DoubleSidedConstants; \
        IN.normalWS = flipSign.z * IN.normalWS; \
        IN.tangentWS = flipSign.x * IN.tangentWS; \
        IN.bitangentWS = flipSign.x * IN.bitangentWS
    #else
        #define FLIP_DOUBLESIDED(IN, FACE) float4 flipSign = IS_FRONT_VFACE(FACE, true, false) ? 1.0 : _DoubleSidedConstants; \
        IN.normalWS = flipSign.z * IN.normalWS
    #endif
#else
    #define FLIP_DOUBLESIDED(IN, OUT)
#endif

void AlphaDiscard(real alpha, real cutoff, real offset = 0.0h)
{
    #ifdef _ALPHATEST_ON
        clip(alpha - cutoff + offset);
    #endif
}

/*{
    #if defined(UNITY_NO_DXT5nm)
        return UnpackNormalRGBNoScale(packedNormal);
    #else
        // Compiler will optimize the scale away
        return UnpackNormalmapRGorAG(packedNormal, 1.0);
    #endif
}*/

/*real3 UnpackNormalScale(real4 packedNormal, real bumpScale)
{
    #if defined(UNITY_NO_DXT5nm)
        return UnpackNormalRGB(packedNormal, bumpScale);
    #else
        return UnpackNormalmapRGorAG(packedNormal, bumpScale);
    #endif
}*/

// A word on normalization of normals:
// For better quality normals should be normalized before and after
// interpolation. 
// 1) In vertex, skinning or blend shapes might vary significantly the lenght of normal. 
// 2) In fragment, because even outputting unit-length normals interpolation can make it non-unit.
// 3) In fragment when using normal map, because mikktspace sets up non orthonormal basis. 
// However we will try to balance performance vs quality here as also let users configure that as 
// shader quality tiers. 
// Low Quality Tier: Normalize either per-vertex or per-pixel depending if normalmap is sampled.
// Medium Quality Tier: Always normalize per-vertex. Normalize per-pixel only if using normal map
// High Quality Tier: Normalize in both vertex and pixel shaders.
real3 NormalizeNormalPerVertex(real3 normalWS)
{
    #if defined(SHADER_QUALITY_LOW) && defined(_NORMALMAP)
        return normalWS;
    #else
        return normalize(normalWS);
    #endif
}

real3 NormalizeNormalPerPixel(real3 normalWS)
{
    #if defined(SHADER_QUALITY_HIGH) || defined(_NORMALMAP)
        return normalize(normalWS);
    #else
        return normalWS;
    #endif
}

// TODO: A similar function should be already available in SRP lib on master. Use that instead
float4 ComputeScreenPos(float4 positionCS)
{
    float4 o = positionCS * 0.5f;
    o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
    o.zw = positionCS.zw;
    return o;
}

real ComputeFogFactor(float z)
{
	#if defined(_TRANSPARENT_ON) || defined(DEFERRED_ON) || defined(POST_PROCESS_FOG)
		#if defined(FOG_LINEAR)
			// factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
			float fogFactor = saturate(z * unity_FogParams.z + unity_FogParams.w);
			return real(fogFactor);
		#elif defined(FOG_EXP) || defined(FOG_EXP2)
			// factor = exp(-(density*z)^2)
			// -density * z computed at vertex
			return real(unity_FogParams.x * z);
		#else
			return 0.0h;
		#endif
	#else
		return 0.0h;
	#endif
}

float FogLerpFactor(real fogFactor)
{
	#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #if defined(FOG_EXP)
            // factor = exp(-density*z)
            // fogFactor = density*z compute at vertex
            fogFactor = saturate(exp2(-fogFactor));
        #elif defined(FOG_EXP2)
            // factor = exp(-(density*z)^2)
            // fogFactor = density*z compute at vertex
            fogFactor = saturate(exp2(-fogFactor*fogFactor));
        #endif
    #endif

	return max(fogFactor, 1 - unity_FogColor.a);
}

float3 MixFogColor(real3 fragColor, real3 fogColor, real fogFactor)
{
	#if !defined(UNITY_COLORSPACE_GAMMA)
		fogColor.rgb = LinearToSRGB(fogColor.rgb);
	#endif

	#if defined(_TRANSPARENT_ON) || defined(DEFERRED_ON) || defined(POST_PROCESS_FOG)
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
			fragColor = lerp(fogColor, fragColor, FogLerpFactor(fogFactor));
		#endif
	#endif

    return fragColor;
}

float3 MixFog(real3 fragColor, real fogFactor)
{
    return MixFogColor(fragColor, unity_FogColor.rgb, fogFactor);
}

float3 CreateRay(float2 postProjectiveSpacePosition)
{
    float3 leftRight = _CamBasisSide * postProjectiveSpacePosition.x * _InvProjMatrix[0].x;
    #if UNITY_UV_STARTS_AT_TOP
	    //postProjectiveSpacePosition.y = -postProjectiveSpacePosition.y;
    #endif
    float3 upDown = _CamBasisUp * postProjectiveSpacePosition.y * _InvProjMatrix[1].y;
    float3 forward = unity_OrthoParams.w > 0 ? 0 : _CamBasisFront;
    return (forward + leftRight + upDown);
}

float3 ReconstructPositionFromLinearDepth(float3 cameraRay, float3 cameraPos, float linearDepth)
{
	float3 result = 0;
	if (unity_OrthoParams.w > 0)
	{
		// при ортогональной проекции луч берет начало в позиции камеры по глубине, но сдвинут от этой точки на cameraRay.xy
		result = cameraPos + cameraRay + _CamBasisFront * linearDepth;
	}
	else
	{
		// при перспективной матрице луч берет начало в точке камеры
		result = cameraPos + cameraRay * linearDepth;
	}

	return result;
}

float LinearEyeDepth(float deviceDepth)
{
    float linearDepth = deviceDepth;
	if (unity_OrthoParams.w > 0)
	{
		/*float near = _ProjectionParams.y;
		float far = _ProjectionParams.z;*/
		// Orthographic: linear depth (with reverse-Z support)
		#if defined(UNITY_REVERSED_Z)
			linearDepth = lerp(_ProjectionParams.z, _ProjectionParams.y, deviceDepth);
		#else
			linearDepth = lerp(_ProjectionParams.y, _ProjectionParams.z, deviceDepth);
		#endif
	}
	else
	{
		linearDepth = LinearEyeDepth(deviceDepth, _ZBufferParams);
	}

    return linearDepth;
}

float3 ReconstructPositionFromDeviceDepth(float3 cameraRay, float3 cameraPos, float deviceDepth)
{
    float linearDepth = LinearEyeDepth(deviceDepth);
	return ReconstructPositionFromLinearDepth(cameraRay, cameraPos, linearDepth);
}

float LinearViewDepth(float3 positionVS, float4 positionCS)
{
    float depth = 0;
    if (unity_OrthoParams.w < 1)
    {
        /*float near = _ProjectionParams.y;
        float far = _ProjectionParams.z;*/
        depth = (-positionVS.z - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
    }
    else
    {
        #if UNITY_REVERSED_Z
            depth = 1 - positionCS.z;
        #else
            depth = positionCS.z;
        #endif
    }

    return depth;
}

// UDN blending https://blog.selfshadow.com/publications/blending-in-detail/
float3 BlendNormalsUDN(float3 n1, float3 n2)
{
	return normalize(float3(n1.xy + n2.xy, n1.z));
}

// https://blog.selfshadow.com/publications/blending-in-detail/
// Модифицировано под WS http://www.gamedev.net/topic/678043-how-to-blend-world-space-normals/?view=findpost&p=5287707
// u - detail normal
// t - base normal
// s - vertex normal
float3 ReorientNormal(float3 u, in float3 t, in float3 s)
{
	// Build the shortest-arc quaternion
	float4 q = float4(cross(s, t), dot(s, t) + 1) / sqrt(2 * (dot(s, t) + 1));

	// Rotate the normal
	return u * (q.w * q.w - dot(q.xyz, q.xyz)) + 2 * q.xyz * dot(q.xyz, u) + 2 * q.w * cross(q.xyz, u);
}

float4x4 GetProbeVolumeWorldToObject()
{
    return unity_ProbeVolumeWorldToObject;
}

void FinalColorOutput(inout float3 color)
{
	#if !defined(UNITY_COLORSPACE_GAMMA)
		color.rgb = LinearToSRGB(color.rgb);
	#endif
}

void FinalColorOutput(inout float4 color)
{
	#if !defined(UNITY_COLORSPACE_GAMMA)
		color.rgb = LinearToSRGB(color.rgb);
	#endif
}

float PackShadowmask(float4 shadowmask)
{
	/*// пакуем 2 канала по 4 бита в fixed (8 байт)
	// 2^4 = 16 [0...15]
	shadowmask.xy *= 15;
	uint packedBits = (uint)shadowmask.x | ((uint)shadowmask.y << 4u);
	return PackByte(packedBits);*/

	// пакуем 4 канала по 4 байта в short (16 байт)
	// 2^4 = 16 [0...15]
	shadowmask.xyzw *= 15;
	uint packedBits = (uint)shadowmask.x | ((uint)shadowmask.y << 4u) | ((uint)shadowmask.z << 8u) | ((uint)shadowmask.w << 12u);
	return PackShort(packedBits);
}

float4 UnpackShadowmask(float packedShadowmask)
{
	/*// распаковываем 2 канала
	// packedShadowmask - это 8-битный float [0...1] в котором запакована shadowmask (см. PackShadowmask)
	uint packedBits = UnpackByte(packedShadowmask);
	return float4((packedBits & 15u) / 15.0f, (packedBits >> 4u) / 15.0f, 1, 1);*/

	// распаковываем 4 канала
	// packedShadowmask - это 16 битный float [0...1] в котором запакована shadowmask (см. PackShadowmask)
	uint packedBits = UnpackShort(packedShadowmask);
	return float4((packedBits & 15u) / 15.0f, ((packedBits >> 4u) & 15u) / 15.0f, ((packedBits >> 8u) & 15u) / 15.0f, ((packedBits >> 12u) & 15u) / 15.0f);
}

uint GetClusterIndex(uint3 clusterUv)
{
	return clusterUv.z * _Clusters.x * _Clusters.y + clusterUv.y * _Clusters.x + clusterUv.x;
}

float3 EncodeNormal(float3 normalWS)
{
    // The sign of the Z component of the normal MUST round-trip through the G-Buffer, otherwise
    // the reconstruction of the tangent frame for anisotropic GGX creates a seam along the Z axis.
    // The constant was eye-balled to not cause artifacts.
    // TODO: find a proper solution. E.g. we could re-shuffle the faces of the octahedron
    // s.t. the sign of the Z component round-trips.
    const float seamThreshold = 1.0 / 1024.0;
    normalWS.z = CopySign(max(seamThreshold, abs(normalWS.z)), normalWS.z);

    // RT1 - 8:8:8:8
    // Our tangent encoding is based on our normal.
    float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
    return PackFloat2To888(saturate(octNormalWS * 0.5 + 0.5));
}

float3 DecodeNormal(float3 packNormalWS)
{
    float2 octNormalWS = Unpack888ToFloat2(packNormalWS);
    return UnpackNormalOctQuadEncode(octNormalWS * 2.0 - 1.0);
}

float4 DecodeNormalAndSmoothness(float4 normalAndSmoothness)
{
	return float4(DecodeNormal(normalAndSmoothness.rgb), normalAndSmoothness.a);
}

#ifdef SUPPORT_FOG_OF_WAR
	float GetFogOfWarFactor(float3 positionWS)
	{
		if (_FogOfWarGlobalFlag < 1)
		{
			return 1;
		}

		float2 fogOfWarCoords = TRANSFORM_TEX(positionWS.xz, _FogOfWarMask);
		float4 fogOfWar = SAMPLE_TEXTURE2D(_FogOfWarMask, s_linear_clamp_sampler, fogOfWarCoords);
		fogOfWar.g *= _FogOfWarColor.a;
		float mask = max(fogOfWar.r, fogOfWar.g) * (1 - fogOfWar.b);
		mask = saturate(mask);
		return mask;
	}

	void ApplyFogOfWarFactor(float fowFactor, inout float3 color)
	{
		color.rgb = lerp(_FogOfWarColor.rgb, color.rgb, fowFactor);
	}

	void ApplyFogOfWar(float3 positionWS, inout float3 color)
	{
		float mask = GetFogOfWarFactor(positionWS);
		color.rgb = lerp(_FogOfWarColor.rgb, color.rgb, mask);
	}
#endif

// Stereo-related bits
#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)

    // Only single-pass stereo instancing uses array indexing
    #if defined(UNITY_STEREO_INSTANCING_ENABLED)
        #define SLICE_ARRAY_INDEX   unity_StereoEyeIndex
    #else
        #define SLICE_ARRAY_INDEX   0
    #endif

    #define TEXTURE2D_X                 TEXTURE2D_ARRAY
    #define TEXTURE2D_X_PARAM           TEXTURE2D_ARRAY_PARAM
    #define TEXTURE2D_X_ARGS            TEXTURE2D_ARRAY_ARGS
    #define TEXTURE2D_X_HALF            TEXTURE2D_ARRAY_HALF
    #define TEXTURE2D_X_FLOAT           TEXTURE2D_ARRAY_FLOAT

    #define LOAD_TEXTURE2D_X(textureName, unCoord2)                         LOAD_TEXTURE2D_ARRAY(textureName, unCoord2, SLICE_ARRAY_INDEX)
    #define LOAD_TEXTURE2D_X_LOD(textureName, unCoord2, lod)                LOAD_TEXTURE2D_ARRAY_LOD(textureName, unCoord2, SLICE_ARRAY_INDEX, lod)    
    #define SAMPLE_TEXTURE2D_X(textureName, samplerName, coord2)            SAMPLE_TEXTURE2D_ARRAY(textureName, samplerName, coord2, SLICE_ARRAY_INDEX)
    #define SAMPLE_TEXTURE2D_X_LOD(textureName, samplerName, coord2, lod)   SAMPLE_TEXTURE2D_ARRAY_LOD(textureName, samplerName, coord2, SLICE_ARRAY_INDEX, lod)
    #define GATHER_TEXTURE2D_X(textureName, samplerName, coord2)            GATHER_TEXTURE2D_ARRAY(textureName, samplerName, coord2, SLICE_ARRAY_INDEX)
    #define GATHER_RED_TEXTURE2D_X(textureName, samplerName, coord2)        GATHER_RED_TEXTURE2D(textureName, samplerName, float3(coord2, SLICE_ARRAY_INDEX))
    #define GATHER_GREEN_TEXTURE2D_X(textureName, samplerName, coord2)      GATHER_GREEN_TEXTURE2D(textureName, samplerName, float3(coord2, SLICE_ARRAY_INDEX))
    #define GATHER_BLUE_TEXTURE2D_X(textureName, samplerName, coord2)       GATHER_BLUE_TEXTURE2D(textureName, samplerName, float3(coord2, SLICE_ARRAY_INDEX))

#else

    #define SLICE_ARRAY_INDEX       0

    #define TEXTURE2D_X                 TEXTURE2D
    #define TEXTURE2D_X_PARAM           TEXTURE2D_PARAM
    #define TEXTURE2D_X_ARGS            TEXTURE2D_ARGS
    #define TEXTURE2D_X_HALF            TEXTURE2D_HALF
    #define TEXTURE2D_X_FLOAT           TEXTURE2D_FLOAT

    #define LOAD_TEXTURE2D_X            LOAD_TEXTURE2D
    #define LOAD_TEXTURE2D_X_LOD        LOAD_TEXTURE2D_LOD
    #define SAMPLE_TEXTURE2D_X          SAMPLE_TEXTURE2D
    #define SAMPLE_TEXTURE2D_X_LOD      SAMPLE_TEXTURE2D_LOD
    #define GATHER_TEXTURE2D_X          GATHER_TEXTURE2D
    #define GATHER_RED_TEXTURE2D_X      GATHER_RED_TEXTURE2D
    #define GATHER_GREEN_TEXTURE2D_X    GATHER_GREEN_TEXTURE2D
    #define GATHER_BLUE_TEXTURE2D_X     GATHER_BLUE_TEXTURE2D

#endif

#if defined(UNITY_SINGLE_PASS_STEREO)
float2 TransformStereoScreenSpaceTex(float2 uv, float w)
{
    // TODO: RVS support can be added here, if LWRP decides to support it
    float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
    return uv.xy * scaleOffset.xy + scaleOffset.zw * w;
}

float2 UnityStereoTransformScreenSpaceTex(float2 uv)
{
    return TransformStereoScreenSpaceTex(saturate(uv), 1.0);
}
#else

#define UnityStereoTransformScreenSpaceTex(uv) uv

#endif // defined(UNITY_SINGLE_PASS_STEREO)

#endif // OWLCAT_PIPELINE_CORE_INCLUDED
