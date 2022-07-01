#ifndef UNIVERSAL_WATER_INPUT_INCLUDED
#define UNIVERSAL_WATER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
TEXTURE2D(_SSPRTextureResult);      SAMPLER(sampler_SSPRTextureResult);
TEXTURE2D(_CameraDepthTexture);     SAMPLER(sampler_CameraDepthTexture);
TEXTURE2D(_CameraOpaqueTexture);    SAMPLER(sampler_CameraOpaqueTexture);

TEXTURE2D(_WaveBaseNormal);         SAMPLER(sampler_WaveBaseNormal);
TEXTURE2D(_WaveAdditionalNormal);   SAMPLER(sampler_WaveAdditionalNormal);

TEXTURE2D(_CausticsTex);            SAMPLER(sampler_CausticsTex);
TEXTURE2D(_FoamTex);                SAMPLER(sampler_FoamTex);

TEXTURECUBE(_EnvCubeMap);           SAMPLER(sampler_EnvCubeMap);                float4 _EnvCubeMap_HDR;

float4 _WaveParams01;
float4 _WaveParams02;
float4 _WaveParams03;
float4 _CausticsParams;
float4 _FoamParams;

float4 _ShallowColor;
float4 _DepthColor;
float _ShallowDepthAdjust;
float _MaxVisibleDepth;


#endif