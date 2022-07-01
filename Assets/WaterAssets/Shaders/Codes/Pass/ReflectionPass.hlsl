#ifndef UNIVERSAL_REFLECTION_PASS_INCLUDED
#define UNIVERSAL_REFLECTION_PASS_INCLUDED
// 反射相关: SSPR SSR 天空盒Cube
half2 Pow6(half2 input) { return input * input * input * input * input * input; }

half4 SampleReflection(Texture2D ssprTex, SamplerState samplerState, float2 uvSS, half3 normalWS, half viewDirWaterDepth)
{
    half2 uv = uvSS + normalWS.zx * half2(0.05, 0.08) * (1 - Pow6(uvSS * 2 - 1)) * saturate(viewDirWaterDepth);
    half4 ssprColor = SAMPLE_TEXTURE2D(ssprTex, samplerState, uv);
    return ssprColor;
}

half3 SampleReflection(TextureCube envCube, SamplerState samplerState, float4 decodeHDR, half3 viewReflDirWS)
{
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(envCube, samplerState, viewReflDirWS, 0);
    return DecodeHDREnvironment(encodedIrradiance, decodeHDR);
}

#endif