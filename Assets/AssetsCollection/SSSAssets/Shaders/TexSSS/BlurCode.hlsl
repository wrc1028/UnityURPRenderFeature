#ifndef CUSTOM_BLUR_INCLUDED
#define CUSTOM_BLUR_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

void Blur3_float(sampler2D OriginTex, SamplerState State, float4 UV, float BlurStepSize, out float4 BlurResult)
{
    float4 col01 = SAMPLE_TEXTURE2D(OriginTex, State, UV);
    BlurResult = col01;
}

#endif