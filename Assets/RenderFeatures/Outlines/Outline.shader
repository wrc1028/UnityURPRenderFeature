Shader "Unlit/Outline"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (1, 1, 1, 1)
        _OutlineScale ("Outline Scale", Range(0, 1)) = 0.2
    }
    SubShader
    {
        Tags {"RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "ShaderModel"="4.5"}
        Cull front
        Pass
        {
            Name "Outline"

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _OutlineColor)
                UNITY_DEFINE_INSTANCED_PROP(float, _OutlineScale)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                // 顶点外扩
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float outlineScale = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _OutlineScale);

                // Vertices in world space spread out
                // float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // float3 normalWS = TransformObjectToWorldDir(input.normalOS.xyz, true);
                // output.positionCS = TransformWorldToHClip(positionWS + normalWS * outlineScale * 0.1);

                // Vertices in clip space spread out
                float4 positionCS = TransformObjectToHClip(input.positionOS.xyz);
                float3 normalCS = TransformWorldToHClipDir(TransformObjectToWorldDir(input.normalOS.xyz, true), true);
                float4 nearUpperRight = mul(UNITY_MATRIX_I_P, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);
                float3 vertexOffset = float3(normalCS.x * aspect, normalCS.y, 0) * outlineScale * positionCS.w * 0.1;
                output.positionCS = float4(positionCS.xyz + vertexOffset, positionCS.w);
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 finalColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _OutlineColor);
                return finalColor;
            }

            ENDHLSL
        }
    }
    Fallback "Diffuse"
}
