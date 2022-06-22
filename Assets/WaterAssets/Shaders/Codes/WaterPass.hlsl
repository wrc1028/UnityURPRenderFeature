#ifndef UNIVERSAL_WATER_PASS_INCLUDED
#define UNIVERSAL_WATER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
    
    return output;
}

half4 WaterFragment(Varyings input) : SV_Target
{
    half3 viewDirWS = normalize(input.viewDirWS);
    float3 positionWS = input.positionWS;
    half3x3 TBNMatrxi = half3x3(input.tangentWS, input.binormalWS, input.normalWS);

    return half4(positionWS, 1);
}

#endif