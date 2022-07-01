Shader "Custom/Water"
{
    Properties
    {
        [Header(Wave)]
        [Normal]_WaveBaseNormal ("Wave Base Normal", 2D) = "bump" {}
        // x : size; y : strength; zw : flow
        _WaveParams01 ("Wave Params 01", vector) = (1, 1, 1, 1)
        [Normal]_WaveAdditionalNormal ("Wave Additional Normal", 2D) = "bump" {}
        _WaveParams02 ("Wave Params 02", vector) = (1, 1, 1, 1)
        _WaveParams03 ("Wave Params 03", vector) = (1, 1, 1, 1)

        [Header(Shadering)]
        _ShallowColor ("Shallow Water Color", Color) = (1, 1, 1, 1)
        _DepthColor ("Depth Water Color", Color) = (1, 1, 1, 1)
        _ShallowDepthAdjust ("Shallow Depth Adjust", Range(0, 1)) = 0.5
        _MaxVisibleDepth ("Max Visible Depth", float) = 1

        [Header(Caustics)]
        _CausticsTex ("Caustics Texture", 2D) = "white" {}
        // x : size; y : intensity; z : uv distortion; w : max visible depth
        _CausticsParams ("Caustics Params", vector) = (1, 1, 1, 1)

        [Header(Foam)]
        _FoamTex ("Foam Texture", 2D) = "white" {}
        // x : size; y : strength; z : uv distortion; w : width
        _FoamParams ("Foam Params", vector) = (1, 1, 1, 1)

        [Header(Common)]
        _EnvCubeMap ("Environment Cube Map", Cube) = "SkyBox" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        // x : size; y : strength; zw : flow
        _NoiseParams ("Noise Params", vector) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Transparent-100" "RenderPipeline" = "UniversalPipeline" }
        Cull off
        Pass
        {
            Name "Water"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex WaterVertex
            #pragma fragment WaterFragment

            #include "WaterInput.hlsl"
            #include "WaterPass.hlsl"

            ENDHLSL
        }
    }
}
