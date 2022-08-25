#ifndef UNIVERSAL_WATER_PASS_INCLUDED
#define UNIVERSAL_WATER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
// 转换贴图
float2 TransformWaterTex(float2 baseUV, float size, float2 flow)
{
    return baseUV * size + _Time.y * size * flow * 0.01;
}
// 法线混合
half3 WhiteoutNormalBlend(half3 n1, half3 n2)
{
	return SafeNormalize(half3(n1.xy + n2.xy, n1.z * n2.z));
}
// pow
half Pow2(half value) { return value * value; }
half Pow5(half value) { return value * value * value * value * value; }
half2 Pow4(half2 value) { return value * value * value * value; }
half2 Pow6(half2 value) { return value * value * value * value * value * value; }
// 通过深度获取世界空间坐标
float3 GetWorldPositionFromDepth(half2 uv, half depth)
{
#if UNITY_UV_STARTS_AT_TOP
    uv.y = 1 - uv.y;
#endif
    float4 positionCS = float4(uv * 2.0 - 1.0, depth, 1);
    float4 positionWS = mul(UNITY_MATRIX_I_VP, positionCS);
    positionWS.xyz /= positionWS.w;
    return positionWS.xyz;
}
// 采样不同深度下的颜色
half4 SimpleWaterColor(float4 shallowColor, float4 depthColor, float depth, half shallowDepthAdjust, half visibleDepth)
{
    half4 color01 = lerp(1, shallowColor, saturate(depth / (visibleDepth * shallowDepthAdjust)));
    half4 color02 = lerp(shallowColor, depthColor, saturate((depth - visibleDepth * shallowDepthAdjust) / (visibleDepth * (1 - shallowDepthAdjust))));
    half4 result = depth < visibleDepth * shallowDepthAdjust ? color01 : color02;
    return result * result;
}
// GGX 高光
half3 BRDFSpecular(half3 normalWS, half3 lightDirWS, half3 viewDirWS, half3 specColor, half roughness)
{
    half3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
    half NdotH = saturate(dot(normalWS, halfDir));
    half LdotH = saturate(dot(lightDirWS, halfDir));

    half roughness2 = roughness * roughness;
    half LdotH2 = LdotH * LdotH;

    half d = NdotH * NdotH * (roughness2 - 1) + 1.00001f;
    half specularTerm = roughness2 / ((d * d) * (LdotH2 * (roughness + 0.5) * 4));
    return specularTerm * specColor;
}
// BlinnPhong 高光
half3 BlinnPhong(half3 normalWS, half3 viewDirWS, Light light)
{
    half3 halfDir = normalize(viewDirWS + light.direction);
    half3 NdotH = saturate(dot(normalWS, halfDir));
    return light.color * smoothstep(0.999, 1, NdotH);
}
// SSR
half3 SampleSimpleSSR(half2 waterProp, half3 positionWS, half4 viewReflectDirWS, half3 envColor, float depth, half2 screneUV)
{
    // float rayDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_RayDepthTexture, sampler_RayDepthTexture_linear_clamp, screneUV).r, _ZBufferParams);
	// waterProp: x:固定距离, y:调整
	// viewReflectDirWS.w: viewNormal.y
	half marchDst = waterProp.x + abs(viewReflectDirWS.w) * 100.0 * waterProp.y;
	half3 marchDestinationPosWS = positionWS + viewReflectDirWS.xyz * marchDst;
	// 空间转换
	half4 marchDestinationPosCS = TransformWorldToHClip(marchDestinationPosWS);
	marchDestinationPosCS /= marchDestinationPosCS.w;
	half2 reflectUV = marchDestinationPosCS.xy * 0.5 + 0.5;
#ifdef UNITY_UV_STARTS_AT_TOP
	reflectUV.y = 1 - reflectUV.y;
#endif
	half2 maskFactor = max(0, 1 - Pow4(marchDestinationPosCS.xy));
	half mask = maskFactor.x * maskFactor.y;
	// 采样
	half3 reflectColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture_linear_clamp, reflectUV).rgb;
	// 获取深度
	float sampleDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture_point_clamp, reflectUV).r, _ZBufferParams);
	reflectColor = depth < sampleDepth ? reflectColor.rgb : envColor.rgb;
	return lerp(envColor, reflectColor, mask);
}
#ifdef _QUALITY_GRADE_HIGH
// 顶点动画
// The Sum of Sines Approximation
float4 SinesWave(float amplitude, float waveLength, float flowSpeed, float2 flowDirection, float3 positionWS)
{
    float w = 2 * rcp(waveLength);
    float s = _Time.y * flowSpeed * w;
    float calc = dot(flowDirection, positionWS.xz) * w + s;
    float offsetY = amplitude * sin(calc);
    half normalX = w * flowDirection.x * amplitude * cos(calc);
    half normalZ = w * flowDirection.y * amplitude * cos(calc);
    return float4(normalize(half3(-normalX, 1, -normalZ)), offsetY);
}
half hash(half p)
{	
    return frac(sin(p) * _WaveRandomSeed);
}

void WaveAnimation(inout float3 positionWS, inout float3 normalWS, half waveCounts)
{
    half3 normals = 0;
    half offsetY = 0;

    [Loop]
    for(int i = 0; i < int(waveCounts); i++)
    {
        half amplitude = hash(i * 3.056 + 5.6941) * _WaveAmplitude;
        half waveLength = hash(i * 9.656 + 6.1) * _WaveLength;
        half flowSpeed = hash(i * 3.159 + 7.486) * _WaveFlowSpeed;
        half2 flowDirection = normalize(half2(hash(i * 7.59 + 2.46), hash(i * 1.29 + 8.96)) * 2 - 1);
        float4 result = SinesWave(amplitude, waveLength, flowSpeed, flowDirection, positionWS);
        normals += result.xyz;
        offsetY += result.w;
    }
    // normalWS = normalize(normals);
    positionWS.y += (offsetY / floor(waveCounts));
}
#endif
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// _QUALITY_GRADE_HIGH _QUALITY_GRADE_MEDIUM _QUALITY_GRADE_LOW
struct Varyings
{
    float4 positionCS   : SV_POSITION;
#ifdef _QUALITY_GRADE_LOW
    float2 baseUV       : TEXCOORD0;
#else
    float4 baseUV       : TEXCOORD0;
#endif
    float4 positionSS   : TEXCOORD1;
    float4 TtoW01       : TEXCOORD2;
    float4 TtoW02       : TEXCOORD3;
    float4 TtoW03       : TEXCOORD4;
    float  fogFactor    : TEXCOORD5;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings WaterVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
#ifdef _QUALITY_GRADE_LOW
    output.baseUV = TransformWaterTex(input.texcoord, _BaseNormalSize, float2(_BaseNormalFlowX, _BaseNormalFlowY));
#else
    output.baseUV.xy = TransformWaterTex(input.texcoord, _BaseNormalSize, float2(_BaseNormalFlowX, _BaseNormalFlowY));
    output.baseUV.zw = TransformWaterTex(input.texcoord, _AdditionalNormalSize, float2(_AdditionalNormalFlowX, _AdditionalNormalFlowY));
#endif

    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldDir(input.normalOS);
    float3 tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
    float3 binormalWS = cross(normalWS, tangentWS) * input.tangentOS.w;
#ifdef _QUALITY_GRADE_HIGH
    WaveAnimation(positionWS, normalWS, _WaveCount);
#endif
    output.positionCS = TransformWorldToHClip(positionWS);
    output.positionSS = ComputeScreenPos(output.positionCS);
    output.TtoW01 = float4(tangentWS, positionWS.x);
    output.TtoW02 = float4(binormalWS, positionWS.y);
    output.TtoW03 = float4(normalWS, positionWS.z);

    return output;
}

half4 WaterFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    half2 screenUV = input.positionSS.xy / input.positionSS.w;
    float3 positionWS = float3(input.TtoW01.w, input.TtoW02.w, input.TtoW03.w);
    half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - positionWS);
    half3x3 TBNMatrxi = half3x3(normalize(input.TtoW01.xyz), normalize(input.TtoW02.xyz), normalize(input.TtoW03.xyz));
    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    // return float4(input.TtoW03.xyz, 1);
    // world space normal
    half3 waveAdditional01NormalTS = 0;
    half2 baseNormalUV = input.baseUV.xy;
#ifndef _QUALITY_GRADE_LOW
    waveAdditional01NormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_WaveBaseNormal, sampler_WaveBaseNormal, input.baseUV.zw), _AdditionalNormalStrength);
    baseNormalUV += waveAdditional01NormalTS.xy * _NormalDistorted * 0.01;
#endif
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_WaveBaseNormal, sampler_WaveBaseNormal, baseNormalUV), _BaseNormalStrength);
#ifdef _QUALITY_GRADE_HIGH
    normalTS = WhiteoutNormalBlend(normalTS, waveAdditional01NormalTS);
#endif
    half3 normalWS = mul(normalTS, TBNMatrxi);
    float eyeLinearOpaqueDepth = LinearEyeDepth(input.positionCS.z, _ZBufferParams);
    half normalAtten = saturate(eyeLinearOpaqueDepth / _NormalAttenDst);
    normalWS = normalize(lerp(normalWS, half3(0, 1, 0), min(0.9, normalAtten)));

    /// ============= Shadering =============
    // depth
    half2 screenEdgeMask = 1 - Pow6(screenUV * 2 - 1);
    // 场景深度和水深度相减，让扰动随着深度变化
    float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture_point_clamp, screenUV);
    float eyeOpaqueDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
    half2 screenDistortion = normalWS.zx * _ScreenDistorted * screenEdgeMask * 0.01 * saturate(eyeOpaqueDepth - eyeLinearOpaqueDepth);
    half rawDepthDistortion = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture_point_clamp, screenUV + screenDistortion);
    float3 positionSWS = GetWorldPositionFromDepth(screenUV, rawDepthDistortion);
    screenDistortion *= positionSWS.y > positionWS.y ? 0 : 1;
    rawDepthDistortion = positionSWS.y > positionWS.y ? rawDepth : rawDepthDistortion;
    float eyeLinearWaterDepth = max(0, LinearEyeDepth(rawDepthDistortion, _ZBufferParams) - eyeLinearOpaqueDepth);

    float verticalWaterDepth = max(0, positionWS.y - positionSWS.y);
    half shallowMask = min(1, eyeLinearWaterDepth * 6);

    half3 finalColor = 0;
    /// ============= refraction color ============= 
    half4 opaqueColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture_linear_clamp, screenUV + screenDistortion);
    half4 waterSimpleColor = SimpleWaterColor(_ShallowColor, _DepthColor, eyeLinearWaterDepth, _ShallowDepthAdjust, _MaxVisibleDepth);
    half3 refractColor = waterSimpleColor.rgb * opaqueColor.rgb * _RefractionIntensity;
    // ============= TODO: SSS =============
// #ifdef _QUALITY_GRADE_HIGH
    // half3 viewDirPWS = normalize(half3(viewDirWS.x, 0, viewDirWS.z));
    // finalColor += Pow2(max(0, dot(viewDirPWS, normalWS))) * mainLight.color * _SSSIntensity * Pow5(1.0 - max(0, dot(half3(0, 1, 0), viewDirWS)));
    // Fast SSS
    // half3 vLTLight = normalize(mainLight.direction + normalWS * _SSSNormalInfluence);
    // half fLTDot = pow(saturate(dot(viewDirWS, -vLTLight)), _SSSPower) * _SSSScale;
    // finalColor += fLTDot * mainLight.color * _SSSColor;
// #endif
    // ============= diffuse =============
    finalColor += max(0, dot(normalWS, mainLight.direction)) * mainLight.color * _ShallowColor.rgb * _DiffuseIntensity;
    // ============= Specular Color GGX TODO: specualr Color and Smothness =============
	finalColor += BRDFSpecular(normalWS, mainLight.direction, viewDirWS, half3(1, 1, 1), 0.002);

    // ============= Reflection =============
    half3 reflectColor = 0;
    half fresnelValue = pow((1.0 - saturate(dot(normalWS, viewDirWS))), _FresnelFactor);
#ifndef _QUALITY_GRADE_LOW
    half3 viewReflDirWS = reflect(-viewDirWS, normalize(normalWS * half3(0.1, 1, 0.1)));
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(_EnvCubeMap, sampler_EnvCubeMap, viewReflDirWS, 0);
    reflectColor = DecodeHDREnvironment(encodedIrradiance, _EnvCubeMap_HDR);
    half4 ssprColor = 0;
    #ifdef _QUALITY_GRADE_HIGH
    half2 ssprDistortion = normalWS.zx * _ReflectionDistorted * screenEdgeMask * saturate(eyeLinearWaterDepth) * 0.02;
    ssprColor = SAMPLE_TEXTURE2D(_SSPRTextureResult, sampler_SSPRTextureResult_linear_clamp, screenUV + ssprDistortion);
    reflectColor = lerp(reflectColor, ssprColor.rgb, ssprColor.a);
    #else
    reflectColor = SampleSimpleSSR(half2(0.1, 50), positionWS, half4(viewReflDirWS, viewDirWS.y), reflectColor, eyeLinearOpaqueDepth, screenUV);
    #endif
    finalColor += lerp(refractColor, reflectColor * _ReflectionIntensity, saturate(fresnelValue + 0.05));
#else
    finalColor += lerp(refractColor, 0.05, saturate(fresnelValue));
#endif

    // ============= caustics =============
#ifndef _QUALITY_GRADE_LOW
    // 三平面映射
    float2 positionCausticsUV01 = positionSWS.zx * _CausticsSize * 0.13 + normalWS.zx * _CausticsDistorted - _Time.y * _BaseNormalSize * float2(_BaseNormalFlowX, _BaseNormalFlowY) * 0.03;
    float2 positionCausticsUV02 = positionSWS.zx * _CausticsSize * 0.09 + normalWS.zx * _CausticsDistorted + _Time.y * _BaseNormalSize * float2(_BaseNormalFlowX, _BaseNormalFlowY) * 0.06;
    half3 causticsColor01 = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, positionCausticsUV01).rgb;
    half3 causticsColor02 = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, positionCausticsUV02).rgb;
    finalColor += min(causticsColor01, causticsColor02) * saturate(exp(-eyeLinearWaterDepth * _CausticsMaxVisibleDepth)) * _CausticsIntensity * min(1, verticalWaterDepth * 8);
#endif
    
    // ============= foam =============
#ifndef _QUALITY_GRADE_LOW
    half mask = saturate(sin(saturate(verticalWaterDepth) * 40 * 3.14159 + _Time.y * 5));
    float2 positionFoamUV = (positionWS + normalWS * _FoamDistorted).zx * _FoamSize * 0.1 - _Time.y * _BaseNormalSize * float2(_BaseNormalFlowX, _BaseNormalFlowY) * 0.03;
    half4 foam = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, positionFoamUV);
    half foamMask = 0;
    // river foam mask
    half riverFoamMask = 1 - min(1, verticalWaterDepth * _FoamWidth);
    foamMask += riverFoamMask * lerp(foam.g, foam.r, riverFoamMask * riverFoamMask) * _FoamIntensity * step(0.001, verticalWaterDepth) * min(1, verticalWaterDepth * 50);
    // wave foam mask
    #ifdef _QUALITY_GRADE_HIGH
    // normalTS.xy *= _WaveFoamNormalStrength;
    // normalTS.z = sqrt(1 - saturate(dot(normalTS.xy, normalTS.xy)));
    // half waveMask = dot(mul(normalTS, TBNMatrxi), half3(0, 1, 0));
    // foamMask += smoothstep(0.7, 1, waveMask) * (1 - normalAtten) * _WaveFoamIntensity * foam.b;
    foamMask += saturate((positionWS.y - _WaveFoamNormalStrength) * 10) * _WaveFoamIntensity * foam.b;
    #endif
    finalColor += foamMask * half3(1, 1, 1);
#endif
    return half4(finalColor, 1);
}

#endif