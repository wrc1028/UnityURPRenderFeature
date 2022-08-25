Shader "Custom/Water"
{
    Properties
    {
        [Header(Wave)]
        [int]_WaveCount ("Wave Count", Range(1, 8)) = 5
        _WaveAmplitude ("Wave Amplitude", float) = 0.3
        _WaveLength ("Wave Length", float) = 1
        _WaveFlowSpeed ("Wave Flow Speed", float) = 1
        _WaveRandomSeed ("Wave Random Seed", float) = 43758.5453123
        [Normal]_WaveBaseNormal ("Water Normal", 2D) = "bump" {}
        _NormalAttenDst ("Normal Atten Dst", float) = 70
        _NormalDistorted ("Normal Distorted", float) = 3
        _BaseNormalSize ("Base Normal Size", float) = 12
        _BaseNormalStrength ("Base Normal Strength", Range(0, 5)) = 1
        _BaseNormalFlowX ("Base Normal Flow X", Range(-1, 1)) = -0.3
        _BaseNormalFlowY ("Base Normal Flow Y", Range(-1, 1)) = 0.25
        _AdditionalNormalSize ("Additional Normal Size", float) = 6
        _AdditionalNormalStrength ("Additional Normal Strength", Range(0, 5)) = 1
        _AdditionalNormalFlowX ("Additional Normal Flow X", Range(-1, 1)) = -0.5
        _AdditionalNormalFlowY ("Additional Normal Flow Y", Range(-1, 1)) = -0.15

        [Header(Shadering)]
        _ShallowColor ("Shallow Water Color", Color) = (1, 1, 1, 1)
        _DepthColor ("Depth Water Color", Color) = (1, 1, 1, 1)
        _ShallowDepthAdjust ("Shallow Depth Adjust", Range(0, 1)) = 0.4
        _MaxVisibleDepth ("Maximum Visible Depth", Range(0.05, 20)) = 3
        _DiffuseIntensity ("Diffuse Intensity", Range(0, 0.5)) = 0.08
        _RefractionIntensity ("Refraction Intensity", Range(0, 2)) = 0.8
        _ScreenDistorted ("Refraction Distorted", Range(0, 10)) = 3

        // [Header(FastSSS)]
        // _SSSIntensity ("SSS Intensity", Range(0, 2)) = 0.05
        // _SSSColor ("SSS Color", Color) = (1, 1, 1, 1)
        // _SSSNormalInfluence ("SSS Normal Influence", Range(-1, 1)) = 0.1
        // _SSSPower ("SSS Power", Range(0.001, 10)) = 1
        // _SSSScale ("SSS Scale", Range(0, 100)) = 10


        [Header(Reflection)]
        _EnvCubeMap ("Environment Cube Map", Cube) = "SkyBox" {}
        _FresnelFactor ("Fresnel Factor", Range(0.01, 10)) = 5
        _ReflectionIntensity ("Reflection Intensity", Range(0, 2)) = 0.6
        _ReflectionDistorted ("Reflection Distorted", Range(0, 5)) = 2

        [Header(Caustics)]
        _CausticsTex ("Caustics Texture", 2D) = "white" {}
        _CausticsSize ("Caustics Size", float) = 2
        _CausticsIntensity ("Caustics Intensity", Range(0, 1)) = 0.3
        _CausticsDistorted ("Caustics Distorted", Range(0, 2)) = 0.29
        _CausticsMaxVisibleDepth ("Caustics Maximum Visible Depth", float) = 1.14

        [Header(Foam)]
        _FoamTex ("Foam Texture", 2D) = "white" {}
        _FoamSize ("Foam Size", float) = 3
        _FoamDistorted ("Foam Distorted", Range(0, 2)) = 0.4

        _FoamIntensity ("Shoreside Foam Intensity", Range(0, 1)) = 0.5
        _FoamWidth ("Shoreside Foam Width", Range(0, 10)) = 2.43

        _WaveFoamIntensity ("Wave Foam Intensity", Range(0, 1)) = 0.26
        _WaveFoamNormalStrength ("Wave Foam Scale", float) = 6.2
    }
    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Transparent-100" "RenderPipeline" = "UniversalPipeline" }
        Cull off
        // ZWrite off
        Pass
        {
            Name "Water"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _QUALITY_GRADE_HIGH _QUALITY_GRADE_MEDIUM _QUALITY_GRADE_LOW
            // #undef _QUALITY_GRADE_HIGH
            // #undef _QUALITY_GRADE_LOW
            // #define _QUALITY_GRADE_MEDIUM
            #pragma vertex WaterVertex
            #pragma fragment WaterFragment


            #include "WaterInput.hlsl"
            #include "WaterPass.hlsl"

            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
    CustomEditor "WaterGUI"
    FallBack "Hidden/InternalErrorShader"
}
