Shader "TL/Effect/SoftDissolved"
// 可控制宽度的
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle(_USE_DISSOLVE_MAP)] _UseDissolveTex ("Use Dissolve Map", float) = 1.0
        _DissolveTex ("R(Noise) G(Dissolve)", 2D) = "white" {}
        _CellNum ("Noise Scale", float) = 8
        _EdgeWidth ("Edge Width", Range(0, 1)) = 0.2
        _Dissolve ("Dissolve", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent"
        }
        LOD 100

        Pass
        {
            Name "SoftDissolved"
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature __ _USE_DISSOLVE_MAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_DissolveTex);
            SAMPLER(sampler_DissolveTex);

            float4 _MainTex_ST;
            float4 _DissolveTex_ST;
            float _CellNum;
            float _EdgeWidth;
            float _Dissolve;

            float4 _Temp;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord   : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv         : VAR_BASE_UV;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _DissolveTex);
                return output;
            }
            float Remap(float oldMin, float oldMax, float newMin, float newMax, float value)
            {
                float weight = (value - oldMin) / (oldMax - oldMin);
                return weight * (newMax - newMin) + newMin;
            }
            half2 RandomDirection(int2 cellID)
            {
                half2 q = half2(dot(cellID, half2(127.1, 311.7)), dot(cellID, half2(269.5, 183.3)));
	            return normalize(-1.0 + 2.0 * frac(sin(q + 0.782) * 43758.5453));
            }
            half PerlinNoise(float2 uv, half cellNum)
            {
                int2 cellID = floor(uv * cellNum);
                half2 cellUV = frac(uv * cellNum);
                
                float a = dot(RandomDirection(cellID), cellUV);
                float b = dot(RandomDirection(cellID + int2(1, 0)), cellUV - half2(1, 0));
                float c = dot(RandomDirection(cellID + int2(0, 1)), cellUV - half2(0, 1));
                float d = dot(RandomDirection(cellID + int2(1, 1)), cellUV - half2(1, 1));

                float2 smoothLocalUV = smoothstep(0.0, 1.0, cellUV);
                float result = lerp(lerp(a, b, smoothLocalUV.x), lerp(c, d, smoothLocalUV.x), smoothLocalUV.y);
                return Remap(-0.707, 0.707, 0, 1, result);
            }

            half4 frag (Varyings input) : SV_TARGET
            {
                // TODO: 从中心处向外扩散，在边缘处添加噪点
                half4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
                half noiseValue = 0;
                half dissolveValue = 0;
                #ifdef _USE_DISSOLVE_MAP
                // 贴图溶解 (0-1)
                    half4 dissolveTex = SAMPLE_TEXTURE2D(_DissolveTex, sampler_DissolveTex, input.uv.zw);
                    noiseValue = dissolveTex.r;
                    dissolveValue = dissolveTex.g;
                #else
                // 从中心溶解 (0-1), 根据相机的长宽比进行调整, 使用程序化噪声
                    half4 nearUpperRight = mul(UNITY_MATRIX_I_P, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
                    half aspect = abs(nearUpperRight.y / nearUpperRight.x);
                    half2 uv = half2(input.uv.x, input.uv.y * aspect);
                    noiseValue = PerlinNoise(uv, _CellNum) * 0.625 + PerlinNoise(uv, _CellNum * 2) * 0.25 + PerlinNoise(uv, _CellNum * 4) * 0.125;
                    dissolveValue = saturate(distance(half2(0.5, 0.5 * aspect), uv));
                #endif
                // 溶解逻辑
                half dissolveCtrl = dissolveValue + _EdgeWidth + noiseValue - _Dissolve * (1 + _EdgeWidth + noiseValue);
                half alpha = smoothstep(0, _EdgeWidth + 0.001, dissolveCtrl); 
                // half alpha = saturate(dissolveCtrl / (_EdgeWidth + 0.001));
                return half4(mainColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
