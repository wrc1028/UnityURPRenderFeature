using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceSubsurfaceScattingFeature : ScriptableRendererFeature
{
    [System.Serializable]
    class RenderSkinSettings
    {
        [SerializeField] internal LayerMask skinLayerMask = 1 << 31;
        [SerializeField] internal string skinLightMode = "SkinDiffuse";
    }
    // 目前先三层
    [System.Serializable]
    class BlurSkinRTSettings
    {
        internal Material blurMaterial;
        internal int blurPassIndex;
        [SerializeField][Min(0.0f)] internal float shallowRadius = 1;
        [SerializeField] internal Color shallowColor;
        [SerializeField][Min(0.0f)] internal float midRadius = 1;
        [SerializeField] internal Color midColor;
        [SerializeField][Min(0.0f)] internal float deepRadius = 1;
        [SerializeField] internal Color deepColor;
    }
    [System.Serializable]
    class BlendSkinSettings
    {
        [SerializeField][Range(0.0f, 1.0f)] internal float shallowStrength;
        [SerializeField][Range(0.0f, 1.0f)] internal float midStrength;
        [SerializeField][Range(0.0f, 1.0f)] internal float deepStrength;
    }


    [SerializeField] private RenderPassEvent m_RenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing; 
    [SerializeField] private RenderSkinSettings m_RenderSkinSettings = new RenderSkinSettings();
    [SerializeField] private BlurSkinRTSettings m_BlurSkinRTSettings = new BlurSkinRTSettings();
    [SerializeField] private BlendSkinSettings m_BlendSkinSettings = new BlendSkinSettings();

    private RenderTargetHandle m_SkinTargetHandle;

    private RenderTargetHandle m_ShallowSkinTargetHandle;
    private RenderTargetHandle m_MidSkinTargetHandle;
    private RenderTargetHandle m_DeepSkinTargetHandle;

    private RenderSkinPass m_RenderSkinPass;
    private BlurSkinRTPass m_BlurSkinRTPass;


    public override void Create()
    {
        m_SkinTargetHandle.Init("_SkinDiffuseTexture");
        m_RenderSkinPass = new RenderSkinPass(m_RenderPassEvent, m_RenderSkinSettings, m_SkinTargetHandle);
        
        m_ShallowSkinTargetHandle.Init("_ShallowSkinDiffuseTexture");
        m_MidSkinTargetHandle.Init("_MidSkinDiffuseTexture");
        m_DeepSkinTargetHandle.Init("_DeepSkinDiffuseTexture");
        if (m_BlurSkinRTSettings.blurMaterial == null)
        {
            m_BlurSkinRTSettings.blurMaterial = new Material(Shader.Find("Hidden/Universal Render Pipeline/SSSSS"));
            m_BlurSkinRTSettings.blurPassIndex = 0;
        }
        m_BlurSkinRTPass = new BlurSkinRTPass(m_RenderPassEvent, m_BlurSkinRTSettings, m_BlendSkinSettings,m_ShallowSkinTargetHandle, m_MidSkinTargetHandle, m_DeepSkinTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderSkinPass);
        m_BlurSkinRTPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_BlurSkinRTPass);
    }
    // 使用漫反射着色器渲染皮肤层
    class RenderSkinPass : ScriptableRenderPass
    {
        private ProfilingSampler m_ProfilingSampler;
        private FilteringSettings m_FilteringSettings;
        private List<ShaderTagId> m_SkinShaderTagIdList = new List<ShaderTagId>();

        private RenderTargetHandle m_SkinTargetHandle;
        private RenderTextureDescriptor m_SkinTargetDescriptor;
        public RenderSkinPass(RenderPassEvent renderPassEvent, RenderSkinSettings settings, RenderTargetHandle skinTargetHandle)
        {
            base.profilingSampler = new ProfilingSampler(nameof(RenderSkinPass));
            this.renderPassEvent = renderPassEvent;
            
            m_ProfilingSampler = new ProfilingSampler("Render Skin Object");
            m_FilteringSettings = new FilteringSettings(RenderQueueRange.opaque, settings.skinLayerMask);
            if (!string.IsNullOrEmpty(settings.skinLightMode)) m_SkinShaderTagIdList.Add(new ShaderTagId(settings.skinLightMode));
            else
            {
                m_SkinShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
                m_SkinShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
                m_SkinShaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));
                m_SkinShaderTagIdList.Add(new ShaderTagId("LightweightForward"));
            }
            m_SkinTargetHandle = skinTargetHandle;
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_SkinTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_SkinTargetDescriptor.msaaSamples = 1;
            cmd.GetTemporaryRT(m_SkinTargetHandle.id, m_SkinTargetDescriptor);
            ConfigureTarget(m_SkinTargetHandle.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;
            DrawingSettings drawingSettings = CreateDrawingSettings(m_SkinShaderTagIdList, ref renderingData, sortingCriteria);
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_SkinTargetHandle.id);
        }
    }
    // 根据扩散剖面和深度模糊皮肤RT
    class BlurSkinRTPass : ScriptableRenderPass
    {
        private ProfilingSampler m_ProfilingSampler;

        private RenderTargetHandle m_ShallowSkinTargetHandle;
        private RenderTargetHandle m_MidSkinTargetHandle;
        private RenderTargetHandle m_DeepSkinTargetHandle;
        private RenderTargetIdentifier m_CurrentColorTarget;
        private RenderTextureDescriptor m_ShallowSkinDescriptor;
        private RenderTextureDescriptor m_MidSkinDescriptor;
        private RenderTextureDescriptor m_DeepSkinDescriptor;

        private BlurSkinRTSettings m_BlurSkinRTSettings;
        private BlendSkinSettings m_BlendSkinSettings;

        public BlurSkinRTPass(RenderPassEvent renderPassEvent, BlurSkinRTSettings settings, BlendSkinSettings blendSkinSettings, 
            RenderTargetHandle shallowTargetHandle, RenderTargetHandle midTargetHandle, RenderTargetHandle deepTargetHandle)
        {
            base.profilingSampler = new ProfilingSampler(nameof(BlurSkinRTPass));
            this.renderPassEvent = renderPassEvent;
            m_BlurSkinRTSettings = settings;
            m_BlendSkinSettings = blendSkinSettings;

            m_ProfilingSampler = new ProfilingSampler("Blur Skin RenderTexture");
            m_ShallowSkinTargetHandle = shallowTargetHandle;
            m_MidSkinTargetHandle = midTargetHandle;
            m_DeepSkinTargetHandle = deepTargetHandle;
        }
        public void Setup(RenderTargetIdentifier currentColorTarget)
        {
            m_CurrentColorTarget = currentColorTarget;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_ShallowSkinDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_ShallowSkinDescriptor.msaaSamples = 1;
            m_MidSkinDescriptor = m_ShallowSkinDescriptor;
            // m_MidSkinDescriptor.width /= 2;
            // m_MidSkinDescriptor.height /= 2;
            m_DeepSkinDescriptor = m_ShallowSkinDescriptor;
            // m_DeepSkinDescriptor.width /= 4;
            // m_DeepSkinDescriptor.height /= 4;

            cmd.GetTemporaryRT(m_ShallowSkinTargetHandle.id, m_ShallowSkinDescriptor);
            cmd.GetTemporaryRT(m_MidSkinTargetHandle.id, m_MidSkinDescriptor);
            cmd.GetTemporaryRT(m_DeepSkinTargetHandle.id, m_DeepSkinDescriptor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                cmd.SetGlobalFloat("_BlurRadius", m_BlurSkinRTSettings.shallowRadius);
                cmd.SetGlobalColor("_SkinColor", m_BlurSkinRTSettings.shallowColor);
                cmd.Blit(null, m_ShallowSkinTargetHandle.Identifier(), m_BlurSkinRTSettings.blurMaterial, m_BlurSkinRTSettings.blurPassIndex);
                cmd.SetGlobalFloat("_BlurRadius", m_BlurSkinRTSettings.midRadius);
                cmd.SetGlobalColor("_SkinColor", m_BlurSkinRTSettings.midColor);
                cmd.Blit(null, m_MidSkinTargetHandle.Identifier(), m_BlurSkinRTSettings.blurMaterial, m_BlurSkinRTSettings.blurPassIndex);
                cmd.SetGlobalFloat("_BlurRadius", m_BlurSkinRTSettings.deepRadius);
                cmd.SetGlobalColor("_SkinColor", m_BlurSkinRTSettings.deepColor);
                cmd.Blit(null, m_DeepSkinTargetHandle.Identifier(), m_BlurSkinRTSettings.blurMaterial, m_BlurSkinRTSettings.blurPassIndex);

                cmd.SetGlobalFloat("_ShallowStrength", m_BlendSkinSettings.shallowStrength);
                cmd.SetGlobalFloat("_Midtrength", m_BlendSkinSettings.midStrength);
                cmd.SetGlobalFloat("_DeepStrength", m_BlendSkinSettings.deepStrength);
                cmd.Blit(null, m_CurrentColorTarget, m_BlurSkinRTSettings.blurMaterial, 1);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_ShallowSkinTargetHandle.id);
            cmd.ReleaseTemporaryRT(m_MidSkinTargetHandle.id);
            cmd.ReleaseTemporaryRT(m_DeepSkinTargetHandle.id);
        }
    }
}


