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

    TEXTURE2D_X(_SourceTex);
    TEXTURE2D_X(_ShallowSkinDiffuseTexture);
    TEXTURE2D_X(_MidSkinDiffuseTexture);
    TEXTURE2D_X(_DeepSkinDiffuseTexture);
    float _ShallowStrength;
    float _Midtrength;
    float _DeepStrength;

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
        return 0.100 * GaussianColor(0.0484, radius, skinColor) + 
               0.118 * GaussianColor(0.1870, radius, skinColor) + 
               0.113 * GaussianColor(0.5470, radius, skinColor) + 
               0.358 * GaussianColor(1.9900, radius, skinColor) + 
               0.078 * GaussianColor(7.4100, radius, skinColor);
    }

    half4 BlurFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        half4 originColor = SAMPLE_TEXTURE2D_X(_SkinDiffuseTexture, sampler_LinearClamp, uv);
        if ((originColor.r + originColor.g + originColor.b) == 0) return 0;

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
        half4 resultColor = originColor * originDiffusionProfile + (c0 + c1 + c2 + c3) * secondDiffusionProfile + (c4 + c5 + c6 + c7) * thirdDiffusionProfile;
        return resultColor;
    }

    half4 BlendFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        half4 baseColor = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv);
        half4 shallowColor = SAMPLE_TEXTURE2D_X(_ShallowSkinDiffuseTexture, sampler_LinearClamp, uv) * _ShallowStrength;
        half4 midColor = SAMPLE_TEXTURE2D_X(_MidSkinDiffuseTexture, sampler_LinearClamp, uv) * _Midtrength;
        half4 deepColor = SAMPLE_TEXTURE2D_X(_DeepSkinDiffuseTexture, sampler_LinearClamp, uv) * _DeepStrength;
        return baseColor + shallowColor + midColor + deepColor;
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
    }

}
