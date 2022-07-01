#ifndef UNIVERSAL_WAVE_PASS_INCLUDED
#define UNIVERSAL_WAVE_PASS_INCLUDED
// 波浪相关: 法线叠加 顶点位移

// 法线混合
half3 WhiteoutNormalBlend(half3 n1, half3 n2, half3 n3)
{
	return normalize(half3(n1.xy + n2.xy + n3.xy, n1.z * n2.z * n3.z));
}
// 采样法线
half3 SampleWaveNormal(Texture2D waveNormalMap, SamplerState samplerState, half4 waveParams, float2 baseUV)
{
    float2 uv = baseUV * waveParams.x + _Time.y * waveParams.x * waveParams.zw * 0.1;
    half3 waveNormalTS = UnpackNormal(SAMPLE_TEXTURE2D(waveNormalMap, samplerState, uv));
    waveNormalTS.xy *= waveParams.y;
    waveNormalTS.z = sqrt(1 - saturate(dot(waveNormalTS.xy, waveNormalTS.xy)));
    return waveNormalTS;
}

#endif