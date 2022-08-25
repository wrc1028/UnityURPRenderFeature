#ifndef UNIVERSAL_WATER_INPUT_INCLUDED
#define UNIVERSAL_WATER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
// _QUALITY_GRADE_HIGH _QUALITY_GRADE_MEDIUM _QUALITY_GRADE_LOW

TEXTURE2D(_CameraDepthTexture);     SAMPLER(sampler_CameraDepthTexture_point_clamp);
TEXTURE2D(_CameraOpaqueTexture);    SAMPLER(sampler_CameraOpaqueTexture_linear_clamp);
TEXTURE2D(_WaveBaseNormal);         SAMPLER(sampler_WaveBaseNormal);

#ifndef _QUALITY_GRADE_LOW
    #ifdef _QUALITY_GRADE_HIGH
TEXTURE2D(_SSPRTextureResult);      SAMPLER(sampler_SSPRTextureResult_linear_clamp);
    #endif
TEXTURE2D(_CausticsTex);            SAMPLER(sampler_CausticsTex);
TEXTURE2D(_FoamTex);                SAMPLER(sampler_FoamTex);
TEXTURECUBE(_EnvCubeMap);           SAMPLER(sampler_EnvCubeMap);
#endif

// x : normal distortion; y : normal atten dst; z : screen distortion; w : TODO: 
// float4 _CommonParams;
// x : size; y : normal strength; zw : flow dir and speed
// float4 _WaveParams01;
// float4 _WaveParams02;
// x : shallow depth adjust; y : max visible depth; z : fake sss intensity; w : refraction intensity
// float4 _ShaderingParams;
// x : fresnel factor; y : TODO: ; z : uv distortion; w : reflection intensity
// float4 _ReflectionParams;
// x : size; y : intensity; z : uv distortion; w : max visible depth
// float4 _CausticsParams;
// x : size; y : intensity; z : uv distortion; w : width
// float4 _FoamParams;
// x : smooth min; y : smooth max; z : normal strength; w : mask intensity
// float4 _WaveFoamParams;
CBUFFER_START(UnityPerMaterial)
float4 _ShallowColor;
float4 _DepthColor;
// float4 _SSSColor;
#ifndef _QUALITY_GRADE_LOW
float4 _EnvCubeMap_HDR;
float _AdditionalNormalSize;
float _AdditionalNormalStrength;
float _AdditionalNormalFlowX;
float _AdditionalNormalFlowY;

float _ReflectionDistorted;
float _ReflectionIntensity;

float _CausticsSize;
float _CausticsIntensity;
float _CausticsDistorted;
float _CausticsMaxVisibleDepth;

float _FoamSize;
float _FoamWidth;
float _FoamDistorted;
float _FoamIntensity;
    #ifdef _QUALITY_GRADE_HIGH
float _WaveCount;
float _WaveAmplitude;
float _WaveLength;
float _WaveFlowSpeed;
float _WaveRandomSeed;
float _WaveFoamNormalStrength;
float _WaveFoamIntensity;
    #endif
#endif

float _NormalDistorted;
float _NormalAttenDst;
float _BaseNormalSize;
float _BaseNormalStrength;
float _BaseNormalFlowX;
float _BaseNormalFlowY;

float _ShallowDepthAdjust;
float _MaxVisibleDepth;
float _DiffuseIntensity;
float _ScreenDistorted;
float _RefractionIntensity;

// float _SSSIntensity;
// float _SSSNormalInfluence;
// float _SSSPower;
// float _SSSScale;

float _FresnelFactor;
CBUFFER_END

#endif