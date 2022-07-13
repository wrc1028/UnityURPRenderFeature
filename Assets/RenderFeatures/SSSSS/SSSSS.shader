Shader "Hidden/Universal Render Pipeline/SSSSS"
{
    // 可以使用Animation曲线代替高斯算法
    HLSLINCLUDE
    #pragma exclude_renderers gles

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

    TEXTURE2D_X(_SkinDiffuseTexture);
    float4 _SkinDiffuseTexture_TexelSize;
    float4 _SkinColor;
    float _BlurRadius;
    TEXTURE2D_X(_CameraDepthTexture);
    TEXTURE2D_X(_SkinDepthTexture);

    TEXTURE2D_X(_SourceTex);
    TEXTURE2D_X(_ShallowSkinDiffuseTexture);
    TEXTURE2D_X(_MidSkinDiffuseTexture);
    TEXTURE2D_X(_DeepSkinDiffuseTexture);
    float _ShallowStrength;
    float _MidStrength;
    float _DeepStrength;

    /// SSSS
    #define DistacneToProjectionWindow 5.671281819617709
    #define DPTimes 1701.384545885313
    #define SamplerSteps 25
    uniform float4 _Kernel[SamplerSteps];
    

    #define SQRT2 1.41421356

    half Gaussian(half variance, half radius, float skinColorChannel)
    {
        half r1 = radius / (0.0001f + skinColorChannel);
        half r2 = r1 * r1;
        return exp(-r2 / (2.0 * variance)) / (2.0 * PI * variance);
    }

    half4 GaussianColor(half variance, half radius, half4 skinColor)
    {
        return half4(Gaussian(variance, radius, skinColor.r), 
                     Gaussian(variance, radius, skinColor.g),
                     Gaussian(variance, radius, skinColor.b), 1);
    }

    half4 DiffusionProfile(half radius, half4 skinColor)
    {
        return 0.07 * GaussianColor(0.036, radius, skinColor) + 
               0.18 * GaussianColor(0.140, radius, skinColor) + 
               0.21 * GaussianColor(0.910, radius, skinColor) + 
               0.29 * GaussianColor(7.000, radius, skinColor);
    }

    half4 BlurFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        half4 originColor = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv);
        if ((originColor.r + originColor.g + originColor.b) == 0) return 0;
        float linearOriginDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_LinearClamp, uv).r;
        float linearSkinDepth = SAMPLE_DEPTH_TEXTURE(_SkinDepthTexture, sampler_LinearClamp, uv).r;
        if (abs(linearOriginDepth - linearSkinDepth) > 0.00001) return 0;

        float2 blurOffset = _SkinDiffuseTexture_TexelSize.xy * _BlurRadius;
        half4 originDiffusionProfile = DiffusionProfile(0, _SkinColor);
        half secondRadius = length(_SkinDiffuseTexture_TexelSize.xy * _BlurRadius) * 16;
        half4 secondDiffusionProfile = DiffusionProfile(secondRadius, _SkinColor);
        half thirdRadius = length(_SkinDiffuseTexture_TexelSize.xy * _BlurRadius) * SQRT2 * 16;
        half4 thirdDiffusionProfile = DiffusionProfile(thirdRadius, _SkinColor);
        half4 c0 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv + float2(0, 1) * blurOffset);
        half4 c1 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv - float2(0, 1) * blurOffset);
        half4 c2 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv - float2(1, 0) * blurOffset);
        half4 c3 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv + float2(1, 0) * blurOffset);
        half4 c4 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv + float2(-1,1) * blurOffset);
        half4 c5 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv + float2(1, 1) * blurOffset);
        half4 c6 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv + float2(1,-1) * blurOffset);
        half4 c7 = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv - float2(1, 1) * blurOffset);
        half4 resultColor = originColor * 0 + (c0 + c1 + c2 + c3) * secondDiffusionProfile + (c4 + c5 + c6 + c7) * thirdDiffusionProfile;
        return resultColor;
    }

    half4 BlendFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        half4 baseColor = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv);
        half4 shallowColor = SAMPLE_TEXTURE2D_X(_ShallowSkinDiffuseTexture, sampler_LinearClamp, uv) * _ShallowStrength;
        half4 midColor = SAMPLE_TEXTURE2D_X(_MidSkinDiffuseTexture, sampler_LinearClamp, uv) * _MidStrength;
        half4 deepColor = SAMPLE_TEXTURE2D_X(_DeepSkinDiffuseTexture, sampler_LinearClamp, uv) * _DeepStrength;
        // half4 sssColor = midColor * half4(0.1, 0.336, 0.344, 1);
        // sssColor += midColor * half4(0.118, 0.198, 0, 1);
        // sssColor += midColor * half4(0.113, 0.007, 0.007, 1);
        // sssColor += deepColor * half4(0.358, 0.004, 0, 1);
        // sssColor += deepColor * half4(0.078, 0, 0, 1);
        // return baseColor + shallowColor * half4(0.233, 0.455, 0.649, 1) + midColor * half4(0.1, 0.336, 0.344, 1) + midColor * half4(0.118, 0.198, 0, 1) + deepColor * half4(0.113, 0.007, 0.007, 1) + deepColor * half4(0.358, 0.004, 0, 1) + deepColor * half4(0.078, 0, 0, 1);
        // return baseColor + shallowColor + midColor + deepColor;
        return baseColor + shallowColor + midColor + deepColor;
    }

    float4 SSS(float2 UV, float2 SSSIntencity)
    {
        half4 sceneColor = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, UV);
        if ((sceneColor.r + sceneColor.g + sceneColor.b) == 0) return 0;
        float linearOriginDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_LinearClamp, UV), _ZBufferParams);
        float blurLength = DistacneToProjectionWindow / linearOriginDepth;
        float2 UVOffset = SSSIntencity * blurLength;
        float4 blurSceneColor = sceneColor;
        blurSceneColor.rgb *= _Kernel[0].rgb;
        [loop]
        for (int i = 1; i < SamplerSteps; i ++)
        {
            float2 SSSUV = UV + _Kernel[i].a * UVOffset;
            float4 SSSSceneColor = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, SSSUV);
            float SSSDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_LinearClamp, SSSUV), _ZBufferParams);
            float SSSScale = saturate(DPTimes * SSSIntencity * abs(linearOriginDepth - SSSDepth));
            SSSSceneColor.rgb *= lerp(SSSSceneColor.rgb, sceneColor.rgb, SSSScale);
            blurSceneColor.rgb += _Kernel[i].rgb * SSSSceneColor.rgb;
        }
        return blurSceneColor;
    }

    float4 BlurXFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        float SSSIntencity = _BlurRadius * _SkinDiffuseTexture_TexelSize.x;
        float4 blurColor = SSS(uv, float2(SSSIntencity, 0));
        return blurColor;
    }

    float4 BlurYFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        float SSSIntencity = _BlurRadius * _SkinDiffuseTexture_TexelSize.y;
        float4 blurColor = SSS(uv, float2(0, SSSIntencity));
        return blurColor;
    }
    ENDHLSL

    // Properties
    // {
    //     _SkinDiffuseTexture ("Source Tex", 2D) = "white" {}
    //     _SkinColor ("Skin Color", Color) = (1, 1, 1, 1)
    //     _BlurRadius ("Blur Radius", float) = 1
    // }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always ZWrite Off Cull Off
        
        Pass
        {
            Name "Blur Skin Texture"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment BlurFragment
            ENDHLSL
        }

        Pass
        {
            Name "Blend Skin Texture"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment BlendFragment
            ENDHLSL
        }

        Pass
        {
            Name "Blur X"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment BlurXFragment
            ENDHLSL
        }

        Pass
        {
            Name "Blur Y"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment BlurYFragment
            ENDHLSL
        }
    }

}
