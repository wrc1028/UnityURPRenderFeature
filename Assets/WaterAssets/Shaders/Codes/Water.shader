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
    }
    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Transparent-100" "RenderPipeline" = "UniversalPipeline" }
        
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
