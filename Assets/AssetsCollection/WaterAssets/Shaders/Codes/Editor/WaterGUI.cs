using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class WaterGUI : ShaderGUI
{
    enum Quality
    {
        High, Medium, Low, 
    }

    class WaterParams
    {
        public string WaveCount = "_WaveCount";
        public string WaveAmplitude  = "_WaveAmplitude";
        public string WaveLength = "_WaveLength";
        public string WaveFlowSpeed  = "_WaveFlowSpeed";
        public string WaveRandomSeed = "_WaveRandomSeed";
        // 法线
        public string NormalDistorted = "_NormalDistorted";
        public string NormalAttenDst = "_NormalAttenDst";
        public string BaseNormalSize = "_BaseNormalSize";
        public string BaseNormalStrength = "_BaseNormalStrength";
        public string BaseNormalFlowX = "_BaseNormalFlowX";
        public string BaseNormalFlowY = "_BaseNormalFlowY";
        public string AdditionalNormalSize = "_AdditionalNormalSize";
        public string AdditionalNormalStrength = "_AdditionalNormalStrength";
        public string AdditionalNormalFlowX = "_AdditionalNormalFlowX";
        public string AdditionalNormalFlowY = "_AdditionalNormalFlowY";
        // 着色
        public string ShallowColor = "_ShallowColor";
        public string DepthColor = "_DepthColor";
        public string ShallowDepthAdjust = "_ShallowDepthAdjust";
        public string MaxVisibleDepth = "_MaxVisibleDepth";
        public string DiffuseIntensity = "_DiffuseIntensity";
        public string FresnelFactor = "_FresnelFactor";
        public string ScreenDistorted = "_ScreenDistorted";
        public string RefractionIntensity = "_RefractionIntensity";
        public string ReflectionDistorted = "_ReflectionDistorted";
        public string ReflectionIntensity = "_ReflectionIntensity";
        // 焦散
        public string CausticsSize = "_CausticsSize";
        public string CausticsIntensity = "_CausticsIntensity";
        public string CausticsDistorted = "_CausticsDistorted";
        public string CausticsMaxVisibleDepth = "_CausticsMaxVisibleDepth";
        // 白沫
        public string FoamSize = "_FoamSize";
        public string FoamWidth = "_FoamWidth";
        public string FoamDistorted = "_FoamDistorted";
        public string FoamIntensity = "_FoamIntensity";
        public string WaveFoamNormalStrength = "_WaveFoamNormalStrength";
        public string WaveFoamIntensity = "_WaveFoamIntensity";
    }
    // _QUALITY_GRADE_HIGH _QUALITY_GRADE_MEDIUM _QUALITY_GRADE_LOW
    private const string highKeyWorld = "_QUALITY_GRADE_HIGH"; 
    private const string mediumKeyWorld = "_QUALITY_GRADE_MEDIUM"; 
    private const string lowKeyWorld = "_QUALITY_GRADE_LOW"; 
    private Quality quality;
    private Material currentMat;

    private bool enableGUI = true;
    private bool waveFold = true;
    private bool normalFold = true;
    private bool shaderingFold = true;
    private bool causticsFold = true;
    private bool foamFold = true;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        currentMat = materialEditor.target as Material;
        if (currentMat.IsKeywordEnabled(highKeyWorld)) quality = Quality.High;
        else if (currentMat.IsKeywordEnabled(mediumKeyWorld)) quality = Quality.Medium;
        else quality = Quality.Low;
        EditorGUI.BeginChangeCheck();
        quality = (Quality)EditorGUILayout.EnumPopup("渲染质量", quality);
        if (EditorGUI.EndChangeCheck())
        {
            switch (quality)
            {
                case Quality.High:
                    currentMat.EnableKeyword(highKeyWorld);
                    currentMat.DisableKeyword(mediumKeyWorld);
                    currentMat.DisableKeyword(lowKeyWorld);
                    break;
                case Quality.Medium:
                    currentMat.DisableKeyword(highKeyWorld);
                    currentMat.EnableKeyword(mediumKeyWorld);
                    currentMat.DisableKeyword(lowKeyWorld);
                    break;
                default:
                    currentMat.DisableKeyword(highKeyWorld);
                    currentMat.DisableKeyword(mediumKeyWorld);
                    currentMat.EnableKeyword(lowKeyWorld);
                    break;
            }
        }
        WaterParams waterParams = new WaterParams();
        enableGUI = EditorGUILayout.Toggle("启用GUI", enableGUI);
        GUILayout.Space(10);
        if (!enableGUI)
        {
            base.OnGUI(materialEditor, properties);
            return;
        }
        if (quality == Quality.High)
        {
            waveFold = EditorGUILayout.BeginFoldoutHeaderGroup(normalFold, "波浪设置");
            materialEditor.RangeProperty(FindProperty(waterParams.WaveCount, properties), "波浪数");
            materialEditor.FloatProperty(FindProperty(waterParams.WaveAmplitude, properties), "波浪基础高度");
            materialEditor.FloatProperty(FindProperty(waterParams.WaveLength, properties), "波浪基础长度");
            materialEditor.FloatProperty(FindProperty(waterParams.WaveFlowSpeed, properties), "波浪基础速度");
            EditorGUILayout.EndFoldoutHeaderGroup();
        }
        GUILayout.Space(10);
        normalFold = EditorGUILayout.BeginFoldoutHeaderGroup(normalFold, "法线设置");
        if (normalFold)
        {
            materialEditor.TextureProperty(FindProperty("_WaveBaseNormal", properties), "法线贴图");
            materialEditor.FloatProperty(FindProperty(waterParams.NormalAttenDst, properties), "法线强度衰减");
            if (quality != Quality.Low)
                materialEditor.FloatProperty(FindProperty(waterParams.NormalDistorted, properties), "法线扭曲强度");
            GUILayout.Space(5);
            materialEditor.FloatProperty(FindProperty(waterParams.BaseNormalSize, properties), "基础法线大小");
            materialEditor.RangeProperty(FindProperty(waterParams.BaseNormalStrength, properties), "基础法线强度");
            materialEditor.RangeProperty(FindProperty(waterParams.BaseNormalFlowX, properties), "基础法线流动方向X");
            materialEditor.RangeProperty(FindProperty(waterParams.BaseNormalFlowY, properties), "基础法线流动方向Y");
            if (quality != Quality.Low)
            {
                GUILayout.Space(5);
                materialEditor.FloatProperty(FindProperty(waterParams.AdditionalNormalSize, properties), "附加法线大小");
                materialEditor.RangeProperty(FindProperty(waterParams.AdditionalNormalStrength, properties), "附加法线强度");
                materialEditor.RangeProperty(FindProperty(waterParams.AdditionalNormalFlowX, properties), "附加法线流动方向X");
                materialEditor.RangeProperty(FindProperty(waterParams.AdditionalNormalFlowY, properties), "附加法线流动方向Y");
            }
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        GUILayout.Space(10);

        shaderingFold = EditorGUILayout.BeginFoldoutHeaderGroup(shaderingFold, "着色");
        if (shaderingFold)
        {
            materialEditor.ColorProperty(FindProperty(waterParams.ShallowColor, properties), "浅水颜色");
            materialEditor.ColorProperty(FindProperty(waterParams.DepthColor, properties), "深水颜色");
            materialEditor.RangeProperty(FindProperty(waterParams.ShallowDepthAdjust, properties), "浅水区域调整");
            materialEditor.RangeProperty(FindProperty(waterParams.MaxVisibleDepth, properties), "最大可视深度");
            GUILayout.Space(5);
            materialEditor.RangeProperty(FindProperty(waterParams.DiffuseIntensity, properties), "漫反射强度");
            GUILayout.Space(5);
            materialEditor.RangeProperty(FindProperty(waterParams.FresnelFactor, properties), "菲涅尔");
            materialEditor.RangeProperty(FindProperty(waterParams.ScreenDistorted, properties), "折射扰动强度");
            materialEditor.RangeProperty(FindProperty(waterParams.RefractionIntensity, properties), "折射强度");
            if (quality != Quality.Low)
            {
                materialEditor.TextureProperty(FindProperty("_EnvCubeMap", properties), "环境贴图");
                materialEditor.RangeProperty(FindProperty(waterParams.ReflectionDistorted, properties), "反射扰动强度");
                materialEditor.RangeProperty(FindProperty(waterParams.ReflectionIntensity, properties), "反射强度");
            }
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        GUILayout.Space(10);

        if (quality != Quality.Low)
        {
            causticsFold = EditorGUILayout.BeginFoldoutHeaderGroup(causticsFold, "焦散");
            if (causticsFold)
            {
                materialEditor.TextureProperty(FindProperty("_CausticsTex", properties), "焦散贴图");
                materialEditor.FloatProperty(FindProperty(waterParams.CausticsSize, properties), "焦散大小");
                materialEditor.RangeProperty(FindProperty(waterParams.CausticsDistorted, properties), "焦散扭曲强度");
                materialEditor.RangeProperty(FindProperty(waterParams.CausticsIntensity, properties), "焦散强度");
                materialEditor.FloatProperty(FindProperty(waterParams.CausticsMaxVisibleDepth, properties), "焦散最大可视距离");
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
            GUILayout.Space(10);

            foamFold = EditorGUILayout.BeginFoldoutHeaderGroup(foamFold, "白沫");
            if (foamFold)
            {
                materialEditor.TextureProperty(FindProperty("_FoamTex", properties), "白沫贴图");
                materialEditor.FloatProperty(FindProperty(waterParams.FoamSize, properties), "白沫大小");
                materialEditor.RangeProperty(FindProperty(waterParams.FoamDistorted, properties), "白沫扭曲强度");

                materialEditor.RangeProperty(FindProperty(waterParams.FoamIntensity, properties), "岸边白沫强度");
                materialEditor.RangeProperty(FindProperty(waterParams.FoamWidth, properties), "岸边白沫宽度");
                if (quality == Quality.High)
                {
                    GUILayout.Space(5);
                    materialEditor.RangeProperty(FindProperty(waterParams.WaveFoamIntensity, properties), "浪尖白沫强度");
                    materialEditor.FloatProperty(FindProperty(waterParams.WaveFoamNormalStrength, properties), "浪尖白沫宽度");
                }
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
            GUILayout.Space(10);

            EditorUtility.SetDirty(materialEditor.target);
            materialEditor.RenderQueueField(); 
        }
    }
}
