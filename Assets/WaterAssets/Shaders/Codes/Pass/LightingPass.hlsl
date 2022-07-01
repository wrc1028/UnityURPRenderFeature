#ifndef UNIVERSAL_LIGHTING_PASS_INCLUDED
#define UNIVERSAL_LIGHTING_PASS_INCLUDED
// 光照相关: 高光 透射 散射
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

half3 SimpleWaterColor(float4 shallowColor, float4 depthColor, float depth, half shallowDepthAdjust, half visibleDepth)
{
    half3 color01 = lerp(1, shallowColor, saturate(depth / (visibleDepth * shallowDepthAdjust)));
    half3 color02 = lerp(shallowColor, depthColor, saturate((depth - visibleDepth * shallowDepthAdjust) / (visibleDepth * (1 - shallowDepthAdjust))));
    half3 result = depth < visibleDepth * shallowDepthAdjust ? color01 : color02;
    return result * result;
}

half Pow5(half value) { return value * value * value * value * value; }

half3 BlinnPhong(half3 normalWS, half3 viewDirWS, Light light)
{
    half3 halfDir = normalize(viewDirWS + light.direction);
    half3 NdotH = saturate(dot(normalWS, halfDir));
    return light.color * smoothstep(0.999, 1, NdotH) * 2;
}

// GGX
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

half3 SampleCaustics(Texture2D causticsTex, SamplerState samplerState, float3 positionSWS, half3 normalWS, float lightDepth, float4 causticsParams)
{
    float2 uv = positionSWS.zx * causticsParams.x + normalWS.zx * causticsParams.z;
    half4 caustics = SAMPLE_TEXTURE2D(causticsTex, samplerState, uv) * saturate(exp(-lightDepth * causticsParams.w));
    return caustics.rgb * causticsParams.y;
}

half3 SampleFoam(Texture2D foamTex, SamplerState samplerState, float2 baseUV, half3 normalWS, float eyeDepth, float4 foamParams)
{
    float2 uv = baseUV * foamParams.x + normalWS.zx * 0.1 * foamParams.z + _Time.y * half2(0.05, 0.02);
    half4 foam = SAMPLE_TEXTURE2D(foamTex, samplerState, uv) * saturate(1 - eyeDepth * foamParams.w);
    return foam.rgb * foamParams.y;
}

half FoamMask(half foamWidth, half foamSpeed, half offset, half depth)
{
    half halfFoamWidth = foamWidth * 0.5;
    half prop1 = sin((_Time.y + offset) * foamSpeed) * halfFoamWidth + halfFoamWidth;
    half prop2 = saturate(abs(depth * foamWidth - prop1));
    half prop3 = (1 - prop2 * prop2) * (1 - depth);
    return prop3;
}

#endif