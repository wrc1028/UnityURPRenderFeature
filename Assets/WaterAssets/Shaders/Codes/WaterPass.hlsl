#ifndef UNIVERSAL_WATER_PASS_INCLUDED
#define UNIVERSAL_WATER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#include "Pass/WavePass.hlsl"
#include "Pass/LightingPass.hlsl"
#include "Pass/ReflectionPass.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;

};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float2 baseUV       : TEXCOORD0;
    float3 positionWS   : TEXCOORD1;
    half3 viewDirWS     : TEXCOORD2;
    half3 normalWS      : TEXCOORD3;
    half3 tangentWS     : TEXCOORD4;
    half3 binormalWS    : TEXCOORD5;
    float4 positionSS   : TEXCOORD6;
};

Varyings WaterVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    output.baseUV = input.texcoord;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.viewDirWS = GetWorldSpaceViewDir(output.positionWS);
    output.normalWS = TransformObjectToWorldDir(input.normalOS);
    output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
    output.binormalWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;
    output.positionSS = ComputeScreenPos(output.positionCS);
    return output;
}

half4 WaterFragment(Varyings input, FRONT_FACE_TYPE VFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    bool isFront = IS_FRONT_VFACE(VFace, true, false);

    half3 viewDirWS = normalize(input.viewDirWS);
    float3 positionWS = input.positionWS;
    half3x3 TBNMatrxi = half3x3(input.tangentWS, input.binormalWS, input.normalWS);
    Light mainLight = GetMainLight();

    half2 screenUV = input.positionSS.xy / input.positionSS.w;
    half rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
    float3 positionSWS = GetWorldPositionFromDepth(screenUV, rawDepth);
    // distortion uv
    // depth
    float eyeLinearOpaqueDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
    float eyeLinearWaterDepth = eyeLinearOpaqueDepth - LinearEyeDepth(input.positionCS.z, _ZBufferParams);
    float verticalWaterDepth = positionWS.y - positionSWS.y;
    half shallowMask = min(1, verticalWaterDepth * 4);
    // sample wave normal TODO: distortion
    half3 waveBaseNormalTS = SampleWaveNormal(_WaveBaseNormal, sampler_WaveBaseNormal, _WaveParams01, input.baseUV);
    half3 waveAdditional01NormalTS = SampleWaveNormal(_WaveAdditionalNormal, sampler_WaveAdditionalNormal, _WaveParams02, input.baseUV);
    half3 waveAdditional02NormalTS = SampleWaveNormal(_WaveAdditionalNormal, sampler_WaveAdditionalNormal, _WaveParams03, input.baseUV);
    // wave normal blend and transform
    half3 waveNormalWS = mul(WhiteoutNormalBlend(waveBaseNormalTS, waveAdditional01NormalTS, waveAdditional02NormalTS), TBNMatrxi);
    
    waveBaseNormalTS.xy *= 0.12;
    waveBaseNormalTS.z = sqrt(1 - saturate(dot(waveBaseNormalTS.xy, waveBaseNormalTS.xy)));

    half3 viewReflDirWS = reflect(-viewDirWS, mul(waveBaseNormalTS, TBNMatrxi));
    float lightWaterDepth = verticalWaterDepth / saturate(dot(mainLight.direction, waveNormalWS));
    
    // refraction color
    half2 distortionalUV = screenUV + waveNormalWS.zx * half2(0.1, 0.2) * (1 - Pow6(screenUV * 2 - 1)) * saturate(eyeLinearWaterDepth);
    half4 opaqueColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, distortionalUV);
    half3 waterSimpleColor = SimpleWaterColor(_ShallowColor, _DepthColor, eyeLinearWaterDepth, _ShallowDepthAdjust, _MaxVisibleDepth);
    half3 refractColor = waterSimpleColor * opaqueColor.rgb;
    // SSS
    half3 sss = saturate(verticalWaterDepth) * _ShallowColor * 0.4 * saturate(dot(viewDirWS, waveNormalWS));
    // Specular Color GGX
    BRDFData brdfData;
    half alpha = 1;
    InitializeBRDFData(half3(0, 0, 0), 0, half3(1, 1, 1), 0.95, alpha, brdfData);
	half3 specualrColor = DirectBDRF(brdfData, waveNormalWS, mainLight.direction, viewDirWS) * mainLight.color;
    // Reflection
    half4 ssprColor = SampleReflection(_SSPRTextureResult, sampler_SSPRTextureResult, screenUV, waveNormalWS, saturate(eyeLinearWaterDepth));
    half3 envColor = SampleReflection(_EnvCubeMap, sampler_EnvCubeMap, _EnvCubeMap_HDR, viewReflDirWS);
    half3 reflectColor = lerp(envColor, ssprColor.rgb, ssprColor.a);
    // 焦散 TODO: distortion
    half3 causticsColor = SampleCaustics(_CausticsTex, sampler_CausticsTex, positionSWS, waveNormalWS, lightWaterDepth, _CausticsParams) * shallowMask;
    // 白沫 TODO: distortion
    half3 foamColor = SampleFoam(_FoamTex, sampler_FoamTex, input.baseUV, waveNormalWS, eyeLinearWaterDepth, _FoamParams) * shallowMask;
    // half foamMask = FoamMask(_FoamParams.x, _FoamParams.y, 0, saturate(eyeLinearWaterDepth * _FoamParams.z)) + FoamMask(_FoamParams.x, _FoamParams.y, 1.5, saturate(eyeLinearWaterDepth * _FoamParams.z));
    // half foamMask = SampleFoam();
    // 雨滴
    // 水下

    half fresnelValue = Pow5((1.0 - saturate(dot(normalize(waveNormalWS), normalize(viewDirWS)))));
    half3 finalColor = lerp(refractColor, reflectColor, fresnelValue) + causticsColor + specualrColor + sss + foamColor.ggg;
    return half4(isFront ? finalColor : opaqueColor, 1); //
}

#endif