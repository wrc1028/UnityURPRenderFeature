Shader "WaterSG"
{
    Properties
    {
        [NoScaleOffset]_WaveNormal("WaveNormal", 2D) = "bump" {}
        _WaveNormalParams("WaveNormalParams", Vector) = (1, 1, 0, 0)
        [NoScaleOffset]_WaveAdditionalNormal("WaveAdditionalNormal", 2D) = "bump" {}
        _WaveAdditionalNormalParams01("WaveAdditionalNormalParams01", Vector) = (1, 1, 0, 0)
        _WaveAdditionalNormalParams02("WaveAdditionalNormalParams02", Vector) = (1, 1, 0, 0)
        _ShallowColor("ShallowColor", Color) = (0, 0, 0, 0)
        _DepthColor("DepthColor", Color) = (0, 0, 0, 0)
        [NoScaleOffset]_EnvCubeMap("EnvCubeMap", CUBE) = "" {}
        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Unlit"
            "Queue"="Transparent"
        }
        Pass
        {
            Name "Pass"
            Tags
            {
                // LightMode: <None>
            }

            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite Off

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 2.0
            #pragma prefer_hlslcc gles
        // #pragma only_renderers gles gles3 glcore d3d11
        #pragma multi_compile_instancing
        #pragma multi_compile_fog
        #pragma vertex vert
        #pragma fragment frag

            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>

            // Keywords
            #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma shader_feature _ _SAMPLE_GI
            // GraphKeywords: <None>

            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_VIEWDIRECTION_WS
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_UNLIT
        #define REQUIRE_DEPTH_TEXTURE
        #define REQUIRE_OPAQUE_TEXTURE
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float4 uv0 : TEXCOORD0;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS;
            float4 texCoord0;
            float3 viewDirectionWS;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
            float3 WorldSpaceViewDirection;
            float3 WorldSpacePosition;
            float4 ScreenPosition;
            float4 uv0;
            float3 TimeParameters;
        };
        struct VertexDescriptionInputs
        {
            float3 ObjectSpaceNormal;
            float3 ObjectSpaceTangent;
            float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
            float4 positionCS : SV_POSITION;
            float3 interp0 : TEXCOORD0;
            float4 interp1 : TEXCOORD1;
            float3 interp2 : TEXCOORD2;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };

            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            output.positionCS = input.positionCS;
            output.interp0.xyz =  input.positionWS;
            output.interp1.xyzw =  input.texCoord0;
            output.interp2.xyz =  input.viewDirectionWS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            output.positionWS = input.interp0.xyz;
            output.texCoord0 = input.interp1.xyzw;
            output.viewDirectionWS = input.interp2.xyz;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }

            // --------------------------------------------------
            // Graph

            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _WaveNormal_TexelSize;
        float4 _WaveNormalParams;
        float4 _WaveAdditionalNormal_TexelSize;
        float4 _WaveAdditionalNormalParams01;
        float4 _WaveAdditionalNormalParams02;
        float4 _ShallowColor;
        float4 _DepthColor;
        CBUFFER_END

        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        SAMPLER(SamplerState_Linear_Clamp);
        TEXTURE2D(_SSPRTextureResult);
        SAMPLER(sampler_SSPRTextureResult);
        float4 _SSPRTextureResult_TexelSize;
        TEXTURE2D(_WaveNormal);
        SAMPLER(sampler_WaveNormal);
        TEXTURE2D(_WaveAdditionalNormal);
        SAMPLER(sampler_WaveAdditionalNormal);
        TEXTURECUBE(_EnvCubeMap);
        SAMPLER(sampler_EnvCubeMap);

            // Graph Functions
            
        void Unity_Multiply_float(float2 A, float2 B, out float2 Out)
        {
            Out = A * B;
        }

        void Unity_Combine_float(float R, float G, float B, float A, out float4 RGBA, out float3 RGB, out float2 RG)
        {
            RGBA = float4(R, G, B, A);
            RGB = float3(R, G, B);
            RG = float2(R, G);
        }

        void Unity_Add_float2(float2 A, float2 B, out float2 Out)
        {
            Out = A + B;
        }

        void Unity_NormalStrength_float(float3 In, float Strength, out float3 Out)
        {
            Out = float3(In.rg * Strength, lerp(1, In.b, saturate(Strength)));
        }

        struct Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c
        {
        };

        void SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(UnityTexture2D Texture2D_facc2d74ae4a431aabff38f53d519faf, float4 Vector4_d39b75aa7703436aa9a53e3a1030a332, float2 Vector2_3457e18aa5904db4ad367138bb14eda5, float Vector1_0cd03821841d44c7b06be789850deded, Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c IN, out float3 WaveNormalTS_1)
        {
            UnityTexture2D _Property_6e3601dfe9ea42c19477eb524caec187_Out_0 = Texture2D_facc2d74ae4a431aabff38f53d519faf;
            float2 _Property_0db3a4056b2643f1ac39698d334439c1_Out_0 = Vector2_3457e18aa5904db4ad367138bb14eda5;
            float4 _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0 = Vector4_d39b75aa7703436aa9a53e3a1030a332;
            float _Split_0658271199cb46438711d3bc02dbdc8d_R_1 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[0];
            float _Split_0658271199cb46438711d3bc02dbdc8d_G_2 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[1];
            float _Split_0658271199cb46438711d3bc02dbdc8d_B_3 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[2];
            float _Split_0658271199cb46438711d3bc02dbdc8d_A_4 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[3];
            float2 _Multiply_292667c9c63143babce5ec49f7f994c9_Out_2;
            Unity_Multiply_float(_Property_0db3a4056b2643f1ac39698d334439c1_Out_0, (_Split_0658271199cb46438711d3bc02dbdc8d_R_1.xx), _Multiply_292667c9c63143babce5ec49f7f994c9_Out_2);
            float4 _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGBA_4;
            float3 _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGB_5;
            float2 _Combine_c2778753d6a243ca99d4ac5369bb2e73_RG_6;
            Unity_Combine_float(_Split_0658271199cb46438711d3bc02dbdc8d_B_3, _Split_0658271199cb46438711d3bc02dbdc8d_A_4, 0, 0, _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGBA_4, _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGB_5, _Combine_c2778753d6a243ca99d4ac5369bb2e73_RG_6);
            float _Property_a16f37cdbc3e4cc2a0ead1e5b06f004c_Out_0 = Vector1_0cd03821841d44c7b06be789850deded;
            float2 _Multiply_d192a5ca8a164c2cb58a0e81ab11e2b3_Out_2;
            Unity_Multiply_float(_Combine_c2778753d6a243ca99d4ac5369bb2e73_RG_6, (_Property_a16f37cdbc3e4cc2a0ead1e5b06f004c_Out_0.xx), _Multiply_d192a5ca8a164c2cb58a0e81ab11e2b3_Out_2);
            float2 _Add_4eb9d03a259c4851ac3d37e6ec00959d_Out_2;
            Unity_Add_float2(_Multiply_292667c9c63143babce5ec49f7f994c9_Out_2, _Multiply_d192a5ca8a164c2cb58a0e81ab11e2b3_Out_2, _Add_4eb9d03a259c4851ac3d37e6ec00959d_Out_2);
            float4 _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0 = SAMPLE_TEXTURE2D(_Property_6e3601dfe9ea42c19477eb524caec187_Out_0.tex, _Property_6e3601dfe9ea42c19477eb524caec187_Out_0.samplerstate, _Add_4eb9d03a259c4851ac3d37e6ec00959d_Out_2);
            _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.rgb = UnpackNormal(_SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0);
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_R_4 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.r;
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_G_5 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.g;
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_B_6 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.b;
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_A_7 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.a;
            float3 _NormalStrength_690adfa3b2a540ddbfec231ab009a072_Out_2;
            Unity_NormalStrength_float((_SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.xyz), _Split_0658271199cb46438711d3bc02dbdc8d_G_2, _NormalStrength_690adfa3b2a540ddbfec231ab009a072_Out_2);
            WaveNormalTS_1 = _NormalStrength_690adfa3b2a540ddbfec231ab009a072_Out_2;
        }

        void Unity_NormalBlend_float(float3 A, float3 B, out float3 Out)
        {
            Out = SafeNormalize(float3(A.rg + B.rg, A.b * B.b));
        }

        void Unity_Saturate_float2(float2 In, out float2 Out)
        {
            Out = saturate(In);
        }

        void Unity_SceneDepth_Eye_float(float4 UV, out float Out)
        {
            Out = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV.xy), _ZBufferParams);
        }

        void Unity_Subtract_float(float A, float B, out float Out)
        {
            Out = A - B;
        }

        void Unity_Saturate_float(float In, out float Out)
        {
            Out = saturate(In);
        }

        void Unity_Lerp_float4(float4 A, float4 B, float4 T, out float4 Out)
        {
            Out = lerp(A, B, T);
        }

        void Unity_SceneColor_float(float4 UV, out float3 Out)
        {
            Out = SHADERGRAPH_SAMPLE_SCENE_COLOR(UV.xy);
        }

        void Unity_Multiply_float(float3 A, float3 B, out float3 Out)
        {
            Out = A * B;
        }

        void Unity_Negate_float3(float3 In, out float3 Out)
        {
            Out = -1 * In;
        }

        void Unity_Reflection_float3(float3 In, float3 Normal, out float3 Out)
        {
            Out = reflect(In, Normal);
        }

        void Unity_FresnelEffect_float(float3 Normal, float3 ViewDir, float Power, out float Out)
        {
            Out = pow((1.0 - saturate(dot(normalize(Normal), normalize(ViewDir)))), Power);
        }

        void Unity_Lerp_float3(float3 A, float3 B, float3 T, out float3 Out)
        {
            Out = lerp(A, B, T);
        }

            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };

        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }

            // Graph Pixel
            struct SurfaceDescription
        {
            float3 BaseColor;
            float Alpha;
        };

        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            float4 _Property_1acc82b0aafd4cbca66cf4594133c48a_Out_0 = _ShallowColor;
            float4 _Property_29296e5853fa4cc9a261d889620e70f9_Out_0 = _DepthColor;
            float4 _ScreenPosition_79de262871004cd0acb2c767a49b0a8e_Out_0 = float4(IN.ScreenPosition.xy / IN.ScreenPosition.w, 0, 0);
            UnityTexture2D _Property_863fd30f26604988834a2a9a679d5aa3_Out_0 = UnityBuildTexture2DStructNoScale(_WaveNormal);
            float4 _Property_0222077ee0964889b29f6b40c30f780a_Out_0 = _WaveNormalParams;
            float4 _UV_5bf078a30dc84c9295e034048513c3f0_Out_0 = IN.uv0;
            Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c _WaveNormal_14a35a12090247e0a67f2b3c606d128c;
            float3 _WaveNormal_14a35a12090247e0a67f2b3c606d128c_WaveNormalTS_1;
            SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(_Property_863fd30f26604988834a2a9a679d5aa3_Out_0, _Property_0222077ee0964889b29f6b40c30f780a_Out_0, (_UV_5bf078a30dc84c9295e034048513c3f0_Out_0.xy), IN.TimeParameters.x, _WaveNormal_14a35a12090247e0a67f2b3c606d128c, _WaveNormal_14a35a12090247e0a67f2b3c606d128c_WaveNormalTS_1);
            UnityTexture2D _Property_9e83c8c26f774fd598f601e0fefe3eda_Out_0 = UnityBuildTexture2DStructNoScale(_WaveAdditionalNormal);
            float4 _Property_131e9c77ee534d61a55c5ba01f4074e6_Out_0 = _WaveAdditionalNormalParams01;
            Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c _WaveNormal_d3069351431a4a1d8c4f1422068c7d81;
            float3 _WaveNormal_d3069351431a4a1d8c4f1422068c7d81_WaveNormalTS_1;
            SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(_Property_9e83c8c26f774fd598f601e0fefe3eda_Out_0, _Property_131e9c77ee534d61a55c5ba01f4074e6_Out_0, (_UV_5bf078a30dc84c9295e034048513c3f0_Out_0.xy), IN.TimeParameters.x, _WaveNormal_d3069351431a4a1d8c4f1422068c7d81, _WaveNormal_d3069351431a4a1d8c4f1422068c7d81_WaveNormalTS_1);
            float4 _Property_0849c128c40243e7a5737572c52cc9df_Out_0 = _WaveAdditionalNormalParams02;
            Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c;
            float3 _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c_WaveNormalTS_1;
            SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(_Property_9e83c8c26f774fd598f601e0fefe3eda_Out_0, _Property_0849c128c40243e7a5737572c52cc9df_Out_0, (_UV_5bf078a30dc84c9295e034048513c3f0_Out_0.xy), IN.TimeParameters.x, _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c, _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c_WaveNormalTS_1);
            float3 _NormalBlend_6b4ab1e8c88548758fc49b673a556f58_Out_2;
            Unity_NormalBlend_float(_WaveNormal_d3069351431a4a1d8c4f1422068c7d81_WaveNormalTS_1, _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c_WaveNormalTS_1, _NormalBlend_6b4ab1e8c88548758fc49b673a556f58_Out_2);
            float3 _NormalBlend_a1cb3fb6c7734fc09338bce6a0d09bdb_Out_2;
            Unity_NormalBlend_float(_WaveNormal_14a35a12090247e0a67f2b3c606d128c_WaveNormalTS_1, _NormalBlend_6b4ab1e8c88548758fc49b673a556f58_Out_2, _NormalBlend_a1cb3fb6c7734fc09338bce6a0d09bdb_Out_2);
            float4 _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1 = _NormalBlend_a1cb3fb6c7734fc09338bce6a0d09bdb_Out_2.rbgr;
            float _Split_4156b7cd5f354d91acd5185600d96880_R_1 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[0];
            float _Split_4156b7cd5f354d91acd5185600d96880_G_2 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[1];
            float _Split_4156b7cd5f354d91acd5185600d96880_B_3 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[2];
            float _Split_4156b7cd5f354d91acd5185600d96880_A_4 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[3];
            float4 _Combine_13f36f0835b748c499f5846453fb191d_RGBA_4;
            float3 _Combine_13f36f0835b748c499f5846453fb191d_RGB_5;
            float2 _Combine_13f36f0835b748c499f5846453fb191d_RG_6;
            Unity_Combine_float(_Split_4156b7cd5f354d91acd5185600d96880_B_3, _Split_4156b7cd5f354d91acd5185600d96880_R_1, 0, 0, _Combine_13f36f0835b748c499f5846453fb191d_RGBA_4, _Combine_13f36f0835b748c499f5846453fb191d_RGB_5, _Combine_13f36f0835b748c499f5846453fb191d_RG_6);
            float2 _Multiply_10325231ace24d84a2bf1f7cdaadfba9_Out_2;
            Unity_Multiply_float(_Combine_13f36f0835b748c499f5846453fb191d_RG_6, float2(0.2, 0.1), _Multiply_10325231ace24d84a2bf1f7cdaadfba9_Out_2);
            float2 _Add_e4011fad48a34944b7ee65f761cb3fa3_Out_2;
            Unity_Add_float2((_ScreenPosition_79de262871004cd0acb2c767a49b0a8e_Out_0.xy), _Multiply_10325231ace24d84a2bf1f7cdaadfba9_Out_2, _Add_e4011fad48a34944b7ee65f761cb3fa3_Out_2);
            float2 _Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1;
            Unity_Saturate_float2(_Add_e4011fad48a34944b7ee65f761cb3fa3_Out_2, _Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1);
            float _SceneDepth_e3d359d8f1a94f14a1655fb97ce65f28_Out_1;
            Unity_SceneDepth_Eye_float((float4(_Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1, 0.0, 1.0)), _SceneDepth_e3d359d8f1a94f14a1655fb97ce65f28_Out_1);
            float4 _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0 = IN.ScreenPosition;
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_R_1 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[0];
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_G_2 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[1];
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_B_3 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[2];
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_A_4 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[3];
            float _Subtract_023f147cb69f4f8c94bdac767643b39c_Out_2;
            Unity_Subtract_float(_SceneDepth_e3d359d8f1a94f14a1655fb97ce65f28_Out_1, _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_A_4, _Subtract_023f147cb69f4f8c94bdac767643b39c_Out_2);
            float _Saturate_fdf7d91e02e0497ea9a42053d3ce7726_Out_1;
            Unity_Saturate_float(_Subtract_023f147cb69f4f8c94bdac767643b39c_Out_2, _Saturate_fdf7d91e02e0497ea9a42053d3ce7726_Out_1);
            float4 _Lerp_8af2ebd4eade4540b199c208b3c788ed_Out_3;
            Unity_Lerp_float4(_Property_1acc82b0aafd4cbca66cf4594133c48a_Out_0, _Property_29296e5853fa4cc9a261d889620e70f9_Out_0, (_Saturate_fdf7d91e02e0497ea9a42053d3ce7726_Out_1.xxxx), _Lerp_8af2ebd4eade4540b199c208b3c788ed_Out_3);
            float3 _SceneColor_df5266277d6e4fda95771c20af95a90f_Out_1;
            Unity_SceneColor_float((float4(_Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1, 0.0, 1.0)), _SceneColor_df5266277d6e4fda95771c20af95a90f_Out_1);
            float3 _Multiply_f272fafe7bf446b390b359eae6adc34c_Out_2;
            Unity_Multiply_float((_Lerp_8af2ebd4eade4540b199c208b3c788ed_Out_3.xyz), _SceneColor_df5266277d6e4fda95771c20af95a90f_Out_1, _Multiply_f272fafe7bf446b390b359eae6adc34c_Out_2);
            UnityTextureCube _Property_ef4d35c05ade493087e75bff879b8ccc_Out_0 = UnityBuildTextureCubeStruct(_EnvCubeMap);
            float3 _Negate_f952970403a44e93a8906dd5f17e790c_Out_1;
            Unity_Negate_float3(IN.WorldSpaceViewDirection, _Negate_f952970403a44e93a8906dd5f17e790c_Out_1);
            float3 _Reflection_3de47d691a6f4c03859e015b82154a08_Out_2;
            Unity_Reflection_float3(_Negate_f952970403a44e93a8906dd5f17e790c_Out_1, (_Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1.xyz), _Reflection_3de47d691a6f4c03859e015b82154a08_Out_2);
            float4 _SampleCubemap_bebbe9308bd14ddd97f0b7cdc7090247_Out_0 = SAMPLE_TEXTURECUBE_LOD(_Property_ef4d35c05ade493087e75bff879b8ccc_Out_0.tex, _Property_ef4d35c05ade493087e75bff879b8ccc_Out_0.samplerstate, _Reflection_3de47d691a6f4c03859e015b82154a08_Out_2, 0);
            UnityTexture2D _Property_6401d6dccb554ccdb83954da40eeaff6_Out_0 = UnityBuildTexture2DStructNoScale(_SSPRTextureResult);
            UnitySamplerState _Property_a4f50fbd0d2543c19843dcdc81affab3_Out_0 = UnityBuildSamplerStateStruct(SamplerState_Linear_Clamp);
            float4 _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0 = SAMPLE_TEXTURE2D(_Property_6401d6dccb554ccdb83954da40eeaff6_Out_0.tex, _Property_a4f50fbd0d2543c19843dcdc81affab3_Out_0.samplerstate, _Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1);
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_R_4 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.r;
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_G_5 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.g;
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_B_6 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.b;
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_A_7 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.a;
            float4 _Lerp_7454b95001d44e6999154918563415ce_Out_3;
            Unity_Lerp_float4(_SampleCubemap_bebbe9308bd14ddd97f0b7cdc7090247_Out_0, _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0, (_SampleTexture2D_80e59f76fd884bc5917c937764b59a24_A_7.xxxx), _Lerp_7454b95001d44e6999154918563415ce_Out_3);
            float _FresnelEffect_65aecbf66ad544ffa7237784f5bf0ccd_Out_3;
            Unity_FresnelEffect_float((_Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1.xyz), IN.WorldSpaceViewDirection, 5, _FresnelEffect_65aecbf66ad544ffa7237784f5bf0ccd_Out_3);
            float3 _Lerp_2983f0023d5e4d968cc9abfde10fb16e_Out_3;
            Unity_Lerp_float3(_Multiply_f272fafe7bf446b390b359eae6adc34c_Out_2, (_Lerp_7454b95001d44e6999154918563415ce_Out_3.xyz), (_FresnelEffect_65aecbf66ad544ffa7237784f5bf0ccd_Out_3.xxx), _Lerp_2983f0023d5e4d968cc9abfde10fb16e_Out_3);
            surface.BaseColor = _Lerp_2983f0023d5e4d968cc9abfde10fb16e_Out_3;
            surface.Alpha = 1;
            return surface;
        }

            // --------------------------------------------------
            // Build Graph Inputs

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);

            output.ObjectSpaceNormal =           input.normalOS;
            output.ObjectSpaceTangent =          input.tangentOS.xyz;
            output.ObjectSpacePosition =         input.positionOS;

            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);





            output.WorldSpaceViewDirection =     input.viewDirectionWS; //TODO: by default normalized in HD, but not in universal
            output.WorldSpacePosition =          input.positionWS;
            output.ScreenPosition =              ComputeScreenPos(TransformWorldToHClip(input.positionWS), _ProjectionParams.x);
            output.uv0 =                         input.texCoord0;
            output.TimeParameters =              _TimeParameters.xyz; // This is mainly for LW as HD overwrite this value
        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

            return output;
        }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/UnlitPass.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite On
        ColorMask 0

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 2.0
            #pragma prefer_hlslcc gles
        // #pragma only_renderers gles gles3 glcore d3d11
        #pragma multi_compile_instancing
        #pragma vertex vert
        #pragma fragment frag

            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>

            // Keywords
            // PassKeywords: <None>
            // GraphKeywords: <None>

            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_SHADOWCASTER
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
        };
        struct VertexDescriptionInputs
        {
            float3 ObjectSpaceNormal;
            float3 ObjectSpaceTangent;
            float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };

            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }

            // --------------------------------------------------
            // Graph

            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _WaveNormal_TexelSize;
        float4 _WaveNormalParams;
        float4 _WaveAdditionalNormal_TexelSize;
        float4 _WaveAdditionalNormalParams01;
        float4 _WaveAdditionalNormalParams02;
        float4 _ShallowColor;
        float4 _DepthColor;
        CBUFFER_END

        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        SAMPLER(SamplerState_Linear_Clamp);
        TEXTURE2D(_SSPRTextureResult);
        SAMPLER(sampler_SSPRTextureResult);
        float4 _SSPRTextureResult_TexelSize;
        TEXTURE2D(_WaveNormal);
        SAMPLER(sampler_WaveNormal);
        TEXTURE2D(_WaveAdditionalNormal);
        SAMPLER(sampler_WaveAdditionalNormal);
        TEXTURECUBE(_EnvCubeMap);
        SAMPLER(sampler_EnvCubeMap);

            // Graph Functions
            // GraphFunctions: <None>

            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };

        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }

            // Graph Pixel
            struct SurfaceDescription
        {
            float Alpha;
        };

        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            surface.Alpha = 1;
            return surface;
        }

            // --------------------------------------------------
            // Build Graph Inputs

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);

            output.ObjectSpaceNormal =           input.normalOS;
            output.ObjectSpaceTangent =          input.tangentOS.xyz;
            output.ObjectSpacePosition =         input.positionOS;

            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);





        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

            return output;
        }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShadowCasterPass.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite On
        ColorMask 0

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 2.0
            #pragma prefer_hlslcc gles
        // #pragma only_renderers gles gles3 glcore d3d11
        #pragma multi_compile_instancing
        #pragma vertex vert
        #pragma fragment frag

            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>

            // Keywords
            // PassKeywords: <None>
            // GraphKeywords: <None>

            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_DEPTHONLY
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
        };
        struct VertexDescriptionInputs
        {
            float3 ObjectSpaceNormal;
            float3 ObjectSpaceTangent;
            float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };

            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }

            // --------------------------------------------------
            // Graph

            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _WaveNormal_TexelSize;
        float4 _WaveNormalParams;
        float4 _WaveAdditionalNormal_TexelSize;
        float4 _WaveAdditionalNormalParams01;
        float4 _WaveAdditionalNormalParams02;
        float4 _ShallowColor;
        float4 _DepthColor;
        CBUFFER_END

        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        SAMPLER(SamplerState_Linear_Clamp);
        TEXTURE2D(_SSPRTextureResult);
        SAMPLER(sampler_SSPRTextureResult);
        float4 _SSPRTextureResult_TexelSize;
        TEXTURE2D(_WaveNormal);
        SAMPLER(sampler_WaveNormal);
        TEXTURE2D(_WaveAdditionalNormal);
        SAMPLER(sampler_WaveAdditionalNormal);
        TEXTURECUBE(_EnvCubeMap);
        SAMPLER(sampler_EnvCubeMap);

            // Graph Functions
            // GraphFunctions: <None>

            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };

        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }

            // Graph Pixel
            struct SurfaceDescription
        {
            float Alpha;
        };

        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            surface.Alpha = 1;
            return surface;
        }

            // --------------------------------------------------
            // Build Graph Inputs

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);

            output.ObjectSpaceNormal =           input.normalOS;
            output.ObjectSpaceTangent =          input.tangentOS.xyz;
            output.ObjectSpacePosition =         input.positionOS;

            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);





        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

            return output;
        }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/DepthOnlyPass.hlsl"

            ENDHLSL
        }
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Unlit"
            "Queue"="Transparent"
        }
        Pass
        {
            Name "Pass"
            Tags
            {
                // LightMode: <None>
            }

            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite Off

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 4.5
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_instancing
        #pragma multi_compile_fog
        #pragma multi_compile _ DOTS_INSTANCING_ON
        #pragma vertex vert
        #pragma fragment frag

            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>

            // Keywords
            #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma shader_feature _ _SAMPLE_GI
            // GraphKeywords: <None>

            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_VIEWDIRECTION_WS
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_UNLIT
        #define REQUIRE_DEPTH_TEXTURE
        #define REQUIRE_OPAQUE_TEXTURE
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float4 uv0 : TEXCOORD0;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS;
            float4 texCoord0;
            float3 viewDirectionWS;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
            float3 WorldSpaceViewDirection;
            float3 WorldSpacePosition;
            float4 ScreenPosition;
            float4 uv0;
            float3 TimeParameters;
        };
        struct VertexDescriptionInputs
        {
            float3 ObjectSpaceNormal;
            float3 ObjectSpaceTangent;
            float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
            float4 positionCS : SV_POSITION;
            float3 interp0 : TEXCOORD0;
            float4 interp1 : TEXCOORD1;
            float3 interp2 : TEXCOORD2;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };

            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            output.positionCS = input.positionCS;
            output.interp0.xyz =  input.positionWS;
            output.interp1.xyzw =  input.texCoord0;
            output.interp2.xyz =  input.viewDirectionWS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            output.positionWS = input.interp0.xyz;
            output.texCoord0 = input.interp1.xyzw;
            output.viewDirectionWS = input.interp2.xyz;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }

            // --------------------------------------------------
            // Graph

            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _WaveNormal_TexelSize;
        float4 _WaveNormalParams;
        float4 _WaveAdditionalNormal_TexelSize;
        float4 _WaveAdditionalNormalParams01;
        float4 _WaveAdditionalNormalParams02;
        float4 _ShallowColor;
        float4 _DepthColor;
        CBUFFER_END

        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        SAMPLER(SamplerState_Linear_Clamp);
        TEXTURE2D(_SSPRTextureResult);
        SAMPLER(sampler_SSPRTextureResult);
        float4 _SSPRTextureResult_TexelSize;
        TEXTURE2D(_WaveNormal);
        SAMPLER(sampler_WaveNormal);
        TEXTURE2D(_WaveAdditionalNormal);
        SAMPLER(sampler_WaveAdditionalNormal);
        TEXTURECUBE(_EnvCubeMap);
        SAMPLER(sampler_EnvCubeMap);

            // Graph Functions
            
        void Unity_Multiply_float(float2 A, float2 B, out float2 Out)
        {
            Out = A * B;
        }

        void Unity_Combine_float(float R, float G, float B, float A, out float4 RGBA, out float3 RGB, out float2 RG)
        {
            RGBA = float4(R, G, B, A);
            RGB = float3(R, G, B);
            RG = float2(R, G);
        }

        void Unity_Add_float2(float2 A, float2 B, out float2 Out)
        {
            Out = A + B;
        }

        void Unity_NormalStrength_float(float3 In, float Strength, out float3 Out)
        {
            Out = float3(In.rg * Strength, lerp(1, In.b, saturate(Strength)));
        }

        struct Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c
        {
        };

        void SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(UnityTexture2D Texture2D_facc2d74ae4a431aabff38f53d519faf, float4 Vector4_d39b75aa7703436aa9a53e3a1030a332, float2 Vector2_3457e18aa5904db4ad367138bb14eda5, float Vector1_0cd03821841d44c7b06be789850deded, Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c IN, out float3 WaveNormalTS_1)
        {
            UnityTexture2D _Property_6e3601dfe9ea42c19477eb524caec187_Out_0 = Texture2D_facc2d74ae4a431aabff38f53d519faf;
            float2 _Property_0db3a4056b2643f1ac39698d334439c1_Out_0 = Vector2_3457e18aa5904db4ad367138bb14eda5;
            float4 _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0 = Vector4_d39b75aa7703436aa9a53e3a1030a332;
            float _Split_0658271199cb46438711d3bc02dbdc8d_R_1 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[0];
            float _Split_0658271199cb46438711d3bc02dbdc8d_G_2 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[1];
            float _Split_0658271199cb46438711d3bc02dbdc8d_B_3 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[2];
            float _Split_0658271199cb46438711d3bc02dbdc8d_A_4 = _Property_b32d7afb78b44683b9ca0cf696261c0b_Out_0[3];
            float2 _Multiply_292667c9c63143babce5ec49f7f994c9_Out_2;
            Unity_Multiply_float(_Property_0db3a4056b2643f1ac39698d334439c1_Out_0, (_Split_0658271199cb46438711d3bc02dbdc8d_R_1.xx), _Multiply_292667c9c63143babce5ec49f7f994c9_Out_2);
            float4 _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGBA_4;
            float3 _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGB_5;
            float2 _Combine_c2778753d6a243ca99d4ac5369bb2e73_RG_6;
            Unity_Combine_float(_Split_0658271199cb46438711d3bc02dbdc8d_B_3, _Split_0658271199cb46438711d3bc02dbdc8d_A_4, 0, 0, _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGBA_4, _Combine_c2778753d6a243ca99d4ac5369bb2e73_RGB_5, _Combine_c2778753d6a243ca99d4ac5369bb2e73_RG_6);
            float _Property_a16f37cdbc3e4cc2a0ead1e5b06f004c_Out_0 = Vector1_0cd03821841d44c7b06be789850deded;
            float2 _Multiply_d192a5ca8a164c2cb58a0e81ab11e2b3_Out_2;
            Unity_Multiply_float(_Combine_c2778753d6a243ca99d4ac5369bb2e73_RG_6, (_Property_a16f37cdbc3e4cc2a0ead1e5b06f004c_Out_0.xx), _Multiply_d192a5ca8a164c2cb58a0e81ab11e2b3_Out_2);
            float2 _Add_4eb9d03a259c4851ac3d37e6ec00959d_Out_2;
            Unity_Add_float2(_Multiply_292667c9c63143babce5ec49f7f994c9_Out_2, _Multiply_d192a5ca8a164c2cb58a0e81ab11e2b3_Out_2, _Add_4eb9d03a259c4851ac3d37e6ec00959d_Out_2);
            float4 _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0 = SAMPLE_TEXTURE2D(_Property_6e3601dfe9ea42c19477eb524caec187_Out_0.tex, _Property_6e3601dfe9ea42c19477eb524caec187_Out_0.samplerstate, _Add_4eb9d03a259c4851ac3d37e6ec00959d_Out_2);
            _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.rgb = UnpackNormal(_SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0);
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_R_4 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.r;
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_G_5 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.g;
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_B_6 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.b;
            float _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_A_7 = _SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.a;
            float3 _NormalStrength_690adfa3b2a540ddbfec231ab009a072_Out_2;
            Unity_NormalStrength_float((_SampleTexture2D_28c543ad692548df8c92a485ddf9ec8b_RGBA_0.xyz), _Split_0658271199cb46438711d3bc02dbdc8d_G_2, _NormalStrength_690adfa3b2a540ddbfec231ab009a072_Out_2);
            WaveNormalTS_1 = _NormalStrength_690adfa3b2a540ddbfec231ab009a072_Out_2;
        }

        void Unity_NormalBlend_float(float3 A, float3 B, out float3 Out)
        {
            Out = SafeNormalize(float3(A.rg + B.rg, A.b * B.b));
        }

        void Unity_Saturate_float2(float2 In, out float2 Out)
        {
            Out = saturate(In);
        }

        void Unity_SceneDepth_Eye_float(float4 UV, out float Out)
        {
            Out = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV.xy), _ZBufferParams);
        }

        void Unity_Subtract_float(float A, float B, out float Out)
        {
            Out = A - B;
        }

        void Unity_Saturate_float(float In, out float Out)
        {
            Out = saturate(In);
        }

        void Unity_Lerp_float4(float4 A, float4 B, float4 T, out float4 Out)
        {
            Out = lerp(A, B, T);
        }

        void Unity_SceneColor_float(float4 UV, out float3 Out)
        {
            Out = SHADERGRAPH_SAMPLE_SCENE_COLOR(UV.xy);
        }

        void Unity_Multiply_float(float3 A, float3 B, out float3 Out)
        {
            Out = A * B;
        }

        void Unity_Negate_float3(float3 In, out float3 Out)
        {
            Out = -1 * In;
        }

        void Unity_Reflection_float3(float3 In, float3 Normal, out float3 Out)
        {
            Out = reflect(In, Normal);
        }

        void Unity_FresnelEffect_float(float3 Normal, float3 ViewDir, float Power, out float Out)
        {
            Out = pow((1.0 - saturate(dot(normalize(Normal), normalize(ViewDir)))), Power);
        }

        void Unity_Lerp_float3(float3 A, float3 B, float3 T, out float3 Out)
        {
            Out = lerp(A, B, T);
        }

            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };

        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }

            // Graph Pixel
            struct SurfaceDescription
        {
            float3 BaseColor;
            float Alpha;
        };

        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            float4 _Property_1acc82b0aafd4cbca66cf4594133c48a_Out_0 = _ShallowColor;
            float4 _Property_29296e5853fa4cc9a261d889620e70f9_Out_0 = _DepthColor;
            float4 _ScreenPosition_79de262871004cd0acb2c767a49b0a8e_Out_0 = float4(IN.ScreenPosition.xy / IN.ScreenPosition.w, 0, 0);
            UnityTexture2D _Property_863fd30f26604988834a2a9a679d5aa3_Out_0 = UnityBuildTexture2DStructNoScale(_WaveNormal);
            float4 _Property_0222077ee0964889b29f6b40c30f780a_Out_0 = _WaveNormalParams;
            float4 _UV_5bf078a30dc84c9295e034048513c3f0_Out_0 = IN.uv0;
            Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c _WaveNormal_14a35a12090247e0a67f2b3c606d128c;
            float3 _WaveNormal_14a35a12090247e0a67f2b3c606d128c_WaveNormalTS_1;
            SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(_Property_863fd30f26604988834a2a9a679d5aa3_Out_0, _Property_0222077ee0964889b29f6b40c30f780a_Out_0, (_UV_5bf078a30dc84c9295e034048513c3f0_Out_0.xy), IN.TimeParameters.x, _WaveNormal_14a35a12090247e0a67f2b3c606d128c, _WaveNormal_14a35a12090247e0a67f2b3c606d128c_WaveNormalTS_1);
            UnityTexture2D _Property_9e83c8c26f774fd598f601e0fefe3eda_Out_0 = UnityBuildTexture2DStructNoScale(_WaveAdditionalNormal);
            float4 _Property_131e9c77ee534d61a55c5ba01f4074e6_Out_0 = _WaveAdditionalNormalParams01;
            Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c _WaveNormal_d3069351431a4a1d8c4f1422068c7d81;
            float3 _WaveNormal_d3069351431a4a1d8c4f1422068c7d81_WaveNormalTS_1;
            SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(_Property_9e83c8c26f774fd598f601e0fefe3eda_Out_0, _Property_131e9c77ee534d61a55c5ba01f4074e6_Out_0, (_UV_5bf078a30dc84c9295e034048513c3f0_Out_0.xy), IN.TimeParameters.x, _WaveNormal_d3069351431a4a1d8c4f1422068c7d81, _WaveNormal_d3069351431a4a1d8c4f1422068c7d81_WaveNormalTS_1);
            float4 _Property_0849c128c40243e7a5737572c52cc9df_Out_0 = _WaveAdditionalNormalParams02;
            Bindings_WaveNormal_3b815be4feaf07844944cbbd5554932c _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c;
            float3 _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c_WaveNormalTS_1;
            SG_WaveNormal_3b815be4feaf07844944cbbd5554932c(_Property_9e83c8c26f774fd598f601e0fefe3eda_Out_0, _Property_0849c128c40243e7a5737572c52cc9df_Out_0, (_UV_5bf078a30dc84c9295e034048513c3f0_Out_0.xy), IN.TimeParameters.x, _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c, _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c_WaveNormalTS_1);
            float3 _NormalBlend_6b4ab1e8c88548758fc49b673a556f58_Out_2;
            Unity_NormalBlend_float(_WaveNormal_d3069351431a4a1d8c4f1422068c7d81_WaveNormalTS_1, _WaveNormal_d7e7fa626eb640f4989e5d377efc2d7c_WaveNormalTS_1, _NormalBlend_6b4ab1e8c88548758fc49b673a556f58_Out_2);
            float3 _NormalBlend_a1cb3fb6c7734fc09338bce6a0d09bdb_Out_2;
            Unity_NormalBlend_float(_WaveNormal_14a35a12090247e0a67f2b3c606d128c_WaveNormalTS_1, _NormalBlend_6b4ab1e8c88548758fc49b673a556f58_Out_2, _NormalBlend_a1cb3fb6c7734fc09338bce6a0d09bdb_Out_2);
            float4 _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1 = _NormalBlend_a1cb3fb6c7734fc09338bce6a0d09bdb_Out_2.rbgr;
            float _Split_4156b7cd5f354d91acd5185600d96880_R_1 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[0];
            float _Split_4156b7cd5f354d91acd5185600d96880_G_2 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[1];
            float _Split_4156b7cd5f354d91acd5185600d96880_B_3 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[2];
            float _Split_4156b7cd5f354d91acd5185600d96880_A_4 = _Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1[3];
            float4 _Combine_13f36f0835b748c499f5846453fb191d_RGBA_4;
            float3 _Combine_13f36f0835b748c499f5846453fb191d_RGB_5;
            float2 _Combine_13f36f0835b748c499f5846453fb191d_RG_6;
            Unity_Combine_float(_Split_4156b7cd5f354d91acd5185600d96880_B_3, _Split_4156b7cd5f354d91acd5185600d96880_R_1, 0, 0, _Combine_13f36f0835b748c499f5846453fb191d_RGBA_4, _Combine_13f36f0835b748c499f5846453fb191d_RGB_5, _Combine_13f36f0835b748c499f5846453fb191d_RG_6);
            float2 _Multiply_10325231ace24d84a2bf1f7cdaadfba9_Out_2;
            Unity_Multiply_float(_Combine_13f36f0835b748c499f5846453fb191d_RG_6, float2(0.2, 0.1), _Multiply_10325231ace24d84a2bf1f7cdaadfba9_Out_2);
            float2 _Add_e4011fad48a34944b7ee65f761cb3fa3_Out_2;
            Unity_Add_float2((_ScreenPosition_79de262871004cd0acb2c767a49b0a8e_Out_0.xy), _Multiply_10325231ace24d84a2bf1f7cdaadfba9_Out_2, _Add_e4011fad48a34944b7ee65f761cb3fa3_Out_2);
            float2 _Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1;
            Unity_Saturate_float2(_Add_e4011fad48a34944b7ee65f761cb3fa3_Out_2, _Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1);
            float _SceneDepth_e3d359d8f1a94f14a1655fb97ce65f28_Out_1;
            Unity_SceneDepth_Eye_float((float4(_Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1, 0.0, 1.0)), _SceneDepth_e3d359d8f1a94f14a1655fb97ce65f28_Out_1);
            float4 _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0 = IN.ScreenPosition;
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_R_1 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[0];
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_G_2 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[1];
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_B_3 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[2];
            float _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_A_4 = _ScreenPosition_a2de542036634aada00d930e0293926a_Out_0[3];
            float _Subtract_023f147cb69f4f8c94bdac767643b39c_Out_2;
            Unity_Subtract_float(_SceneDepth_e3d359d8f1a94f14a1655fb97ce65f28_Out_1, _Split_0fd7e55bc69f40b5a9b2a2abade00ca1_A_4, _Subtract_023f147cb69f4f8c94bdac767643b39c_Out_2);
            float _Saturate_fdf7d91e02e0497ea9a42053d3ce7726_Out_1;
            Unity_Saturate_float(_Subtract_023f147cb69f4f8c94bdac767643b39c_Out_2, _Saturate_fdf7d91e02e0497ea9a42053d3ce7726_Out_1);
            float4 _Lerp_8af2ebd4eade4540b199c208b3c788ed_Out_3;
            Unity_Lerp_float4(_Property_1acc82b0aafd4cbca66cf4594133c48a_Out_0, _Property_29296e5853fa4cc9a261d889620e70f9_Out_0, (_Saturate_fdf7d91e02e0497ea9a42053d3ce7726_Out_1.xxxx), _Lerp_8af2ebd4eade4540b199c208b3c788ed_Out_3);
            float3 _SceneColor_df5266277d6e4fda95771c20af95a90f_Out_1;
            Unity_SceneColor_float((float4(_Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1, 0.0, 1.0)), _SceneColor_df5266277d6e4fda95771c20af95a90f_Out_1);
            float3 _Multiply_f272fafe7bf446b390b359eae6adc34c_Out_2;
            Unity_Multiply_float((_Lerp_8af2ebd4eade4540b199c208b3c788ed_Out_3.xyz), _SceneColor_df5266277d6e4fda95771c20af95a90f_Out_1, _Multiply_f272fafe7bf446b390b359eae6adc34c_Out_2);
            UnityTextureCube _Property_ef4d35c05ade493087e75bff879b8ccc_Out_0 = UnityBuildTextureCubeStruct(_EnvCubeMap);
            float3 _Negate_f952970403a44e93a8906dd5f17e790c_Out_1;
            Unity_Negate_float3(IN.WorldSpaceViewDirection, _Negate_f952970403a44e93a8906dd5f17e790c_Out_1);
            float3 _Reflection_3de47d691a6f4c03859e015b82154a08_Out_2;
            Unity_Reflection_float3(_Negate_f952970403a44e93a8906dd5f17e790c_Out_1, (_Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1.xyz), _Reflection_3de47d691a6f4c03859e015b82154a08_Out_2);
            float4 _SampleCubemap_bebbe9308bd14ddd97f0b7cdc7090247_Out_0 = SAMPLE_TEXTURECUBE_LOD(_Property_ef4d35c05ade493087e75bff879b8ccc_Out_0.tex, _Property_ef4d35c05ade493087e75bff879b8ccc_Out_0.samplerstate, _Reflection_3de47d691a6f4c03859e015b82154a08_Out_2, 0);
            UnityTexture2D _Property_6401d6dccb554ccdb83954da40eeaff6_Out_0 = UnityBuildTexture2DStructNoScale(_SSPRTextureResult);
            UnitySamplerState _Property_a4f50fbd0d2543c19843dcdc81affab3_Out_0 = UnityBuildSamplerStateStruct(SamplerState_Linear_Clamp);
            float4 _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0 = SAMPLE_TEXTURE2D(_Property_6401d6dccb554ccdb83954da40eeaff6_Out_0.tex, _Property_a4f50fbd0d2543c19843dcdc81affab3_Out_0.samplerstate, _Saturate_6114a0b95afe49b38adcf023e19593eb_Out_1);
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_R_4 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.r;
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_G_5 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.g;
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_B_6 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.b;
            float _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_A_7 = _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0.a;
            float4 _Lerp_7454b95001d44e6999154918563415ce_Out_3;
            Unity_Lerp_float4(_SampleCubemap_bebbe9308bd14ddd97f0b7cdc7090247_Out_0, _SampleTexture2D_80e59f76fd884bc5917c937764b59a24_RGBA_0, (_SampleTexture2D_80e59f76fd884bc5917c937764b59a24_A_7.xxxx), _Lerp_7454b95001d44e6999154918563415ce_Out_3);
            float _FresnelEffect_65aecbf66ad544ffa7237784f5bf0ccd_Out_3;
            Unity_FresnelEffect_float((_Swizzle_53032c91ec6a42308b46181b3b7bd481_Out_1.xyz), IN.WorldSpaceViewDirection, 5, _FresnelEffect_65aecbf66ad544ffa7237784f5bf0ccd_Out_3);
            float3 _Lerp_2983f0023d5e4d968cc9abfde10fb16e_Out_3;
            Unity_Lerp_float3(_Multiply_f272fafe7bf446b390b359eae6adc34c_Out_2, (_Lerp_7454b95001d44e6999154918563415ce_Out_3.xyz), (_FresnelEffect_65aecbf66ad544ffa7237784f5bf0ccd_Out_3.xxx), _Lerp_2983f0023d5e4d968cc9abfde10fb16e_Out_3);
            surface.BaseColor = _Lerp_2983f0023d5e4d968cc9abfde10fb16e_Out_3;
            surface.Alpha = 1;
            return surface;
        }

            // --------------------------------------------------
            // Build Graph Inputs

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);

            output.ObjectSpaceNormal =           input.normalOS;
            output.ObjectSpaceTangent =          input.tangentOS.xyz;
            output.ObjectSpacePosition =         input.positionOS;

            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);





            output.WorldSpaceViewDirection =     input.viewDirectionWS; //TODO: by default normalized in HD, but not in universal
            output.WorldSpacePosition =          input.positionWS;
            output.ScreenPosition =              ComputeScreenPos(TransformWorldToHClip(input.positionWS), _ProjectionParams.x);
            output.uv0 =                         input.texCoord0;
            output.TimeParameters =              _TimeParameters.xyz; // This is mainly for LW as HD overwrite this value
        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

            return output;
        }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/UnlitPass.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite On
        ColorMask 0

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 4.5
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON
        #pragma vertex vert
        #pragma fragment frag

            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>

            // Keywords
            // PassKeywords: <None>
            // GraphKeywords: <None>

            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_SHADOWCASTER
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
        };
        struct VertexDescriptionInputs
        {
            float3 ObjectSpaceNormal;
            float3 ObjectSpaceTangent;
            float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };

            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }

            // --------------------------------------------------
            // Graph

            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _WaveNormal_TexelSize;
        float4 _WaveNormalParams;
        float4 _WaveAdditionalNormal_TexelSize;
        float4 _WaveAdditionalNormalParams01;
        float4 _WaveAdditionalNormalParams02;
        float4 _ShallowColor;
        float4 _DepthColor;
        CBUFFER_END

        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        SAMPLER(SamplerState_Linear_Clamp);
        TEXTURE2D(_SSPRTextureResult);
        SAMPLER(sampler_SSPRTextureResult);
        float4 _SSPRTextureResult_TexelSize;
        TEXTURE2D(_WaveNormal);
        SAMPLER(sampler_WaveNormal);
        TEXTURE2D(_WaveAdditionalNormal);
        SAMPLER(sampler_WaveAdditionalNormal);
        TEXTURECUBE(_EnvCubeMap);
        SAMPLER(sampler_EnvCubeMap);

            // Graph Functions
            // GraphFunctions: <None>

            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };

        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }

            // Graph Pixel
            struct SurfaceDescription
        {
            float Alpha;
        };

        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            surface.Alpha = 1;
            return surface;
        }

            // --------------------------------------------------
            // Build Graph Inputs

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);

            output.ObjectSpaceNormal =           input.normalOS;
            output.ObjectSpaceTangent =          input.tangentOS.xyz;
            output.ObjectSpacePosition =         input.positionOS;

            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);





        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

            return output;
        }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShadowCasterPass.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite On
        ColorMask 0

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 4.5
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON
        #pragma vertex vert
        #pragma fragment frag

            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>

            // Keywords
            // PassKeywords: <None>
            // GraphKeywords: <None>

            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_DEPTHONLY
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
        };
        struct VertexDescriptionInputs
        {
            float3 ObjectSpaceNormal;
            float3 ObjectSpaceTangent;
            float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
            float4 positionCS : SV_POSITION;
            #if UNITY_ANY_INSTANCING_ENABLED
            uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };

            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }

            // --------------------------------------------------
            // Graph

            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _WaveNormal_TexelSize;
        float4 _WaveNormalParams;
        float4 _WaveAdditionalNormal_TexelSize;
        float4 _WaveAdditionalNormalParams01;
        float4 _WaveAdditionalNormalParams02;
        float4 _ShallowColor;
        float4 _DepthColor;
        CBUFFER_END

        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        SAMPLER(SamplerState_Linear_Clamp);
        TEXTURE2D(_SSPRTextureResult);
        SAMPLER(sampler_SSPRTextureResult);
        float4 _SSPRTextureResult_TexelSize;
        TEXTURE2D(_WaveNormal);
        SAMPLER(sampler_WaveNormal);
        TEXTURE2D(_WaveAdditionalNormal);
        SAMPLER(sampler_WaveAdditionalNormal);
        TEXTURECUBE(_EnvCubeMap);
        SAMPLER(sampler_EnvCubeMap);

            // Graph Functions
            // GraphFunctions: <None>

            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };

        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }

            // Graph Pixel
            struct SurfaceDescription
        {
            float Alpha;
        };

        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            surface.Alpha = 1;
            return surface;
        }

            // --------------------------------------------------
            // Build Graph Inputs

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);

            output.ObjectSpaceNormal =           input.normalOS;
            output.ObjectSpaceTangent =          input.tangentOS.xyz;
            output.ObjectSpacePosition =         input.positionOS;

            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);





        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

            return output;
        }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/DepthOnlyPass.hlsl"

            ENDHLSL
        }
    }
    FallBack "Hidden/Shader Graph/FallbackError"
}