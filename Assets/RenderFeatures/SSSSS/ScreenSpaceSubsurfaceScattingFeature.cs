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

    private RenderTargetHandle m_SkinColorTargetHandle;
    private RenderTargetHandle m_SkinDepthTargetHandle;

    private RenderTargetHandle m_ShallowSkinTargetHandle;
    private RenderTargetHandle m_MidSkinTargetHandle;
    private RenderTargetHandle m_DeepSkinTargetHandle;

    private RenderSkinPass m_RenderSkinPass;
    private BlurSkinRTPass m_BlurSkinRTPass;


    public override void Create()
    {
        m_SkinColorTargetHandle.Init("_SkinDiffuseTexture");
        m_SkinDepthTargetHandle.Init("_SkinDepthTexture");
        m_RenderSkinPass = new RenderSkinPass(m_RenderPassEvent, m_RenderSkinSettings, m_SkinColorTargetHandle, m_SkinDepthTargetHandle);
        
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

        private RenderTargetHandle m_SkinColorTargetHandle;
        private RenderTargetHandle m_SkinDepthTargetHandle;
        private RenderTextureDescriptor m_SkinTargetDescriptor;
        private RenderTextureDescriptor m_DepthTargetDescriptor;
        public RenderSkinPass(RenderPassEvent renderPassEvent, RenderSkinSettings settings, RenderTargetHandle skinTargetHandle, RenderTargetHandle depthTargetHandle)
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
            m_SkinColorTargetHandle = skinTargetHandle;
            m_SkinDepthTargetHandle = depthTargetHandle;
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_SkinTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_SkinTargetDescriptor.msaaSamples = 1;
            m_DepthTargetDescriptor = new RenderTextureDescriptor(m_SkinTargetDescriptor.width, m_SkinTargetDescriptor.height, RenderTextureFormat.Depth, m_SkinTargetDescriptor.depthBufferBits);
            cmd.GetTemporaryRT(m_SkinColorTargetHandle.id, m_SkinTargetDescriptor);
            cmd.GetTemporaryRT(m_SkinDepthTargetHandle.id, m_DepthTargetDescriptor);
            ConfigureTarget(m_SkinColorTargetHandle.Identifier(), m_SkinDepthTargetHandle.Identifier());
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
            cmd.ReleaseTemporaryRT(m_SkinColorTargetHandle.id);
        }
    }
    // 根据扩散剖面和深度模糊皮肤RT
    class BlurSkinRTPass : ScriptableRenderPass
    {
        private ProfilingSampler m_ProfilingSampler;

        private RenderTargetHandle m_ShallowSkinTargetHandle;
        private RenderTargetHandle m_MidSkinTargetHandle;
        private RenderTargetHandle m_DeepSkinTargetHandle;
        private RenderTargetHandle m_TempTargetHandle;
        private RenderTargetHandle m_CurrentColorTarget;
        private RenderTextureDescriptor m_ShallowSkinDescriptor;
        private RenderTextureDescriptor m_MidSkinDescriptor;
        private RenderTextureDescriptor m_DeepSkinDescriptor;
        private RenderTextureDescriptor m_TempDescriptor;

        private BlurSkinRTSettings m_BlurSkinRTSettings;
        private BlendSkinSettings m_BlendSkinSettings;

        private List<Vector4> kernels = new List<Vector4>();

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
            m_TempTargetHandle.Init("_TempRenderTarget");
        }
        public void Setup(RenderTargetIdentifier currentColorTarget)
        {
            m_CurrentColorTarget = new RenderTargetHandle(currentColorTarget);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_ShallowSkinDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_ShallowSkinDescriptor.msaaSamples = 1;
            m_MidSkinDescriptor = m_ShallowSkinDescriptor;
            // m_MidSkinDescriptor.width /= 2;
            // m_MidSkinDescriptor.height /= 2;
            m_DeepSkinDescriptor = m_ShallowSkinDescriptor;
            m_DeepSkinDescriptor.width /= 4;
            m_DeepSkinDescriptor.height /= 4;
            m_TempDescriptor = renderingData.cameraData.cameraTargetDescriptor;

            cmd.GetTemporaryRT(m_ShallowSkinTargetHandle.id, m_ShallowSkinDescriptor);
            cmd.GetTemporaryRT(m_MidSkinTargetHandle.id, m_MidSkinDescriptor);
            cmd.GetTemporaryRT(m_DeepSkinTargetHandle.id, m_DeepSkinDescriptor);
            cmd.GetTemporaryRT(m_TempTargetHandle.id, m_TempDescriptor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                cmd.Blit(m_CurrentColorTarget.Identifier(), m_TempTargetHandle.Identifier());
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
                cmd.SetGlobalFloat("_MidStrength", m_BlendSkinSettings.midStrength);
                cmd.SetGlobalFloat("_DeepStrength", m_BlendSkinSettings.deepStrength);
                
                // Vector3 SSSC = Vector3.Normalize(new Vector3(m_BlurSkinRTSettings.shallowColor.r, m_BlurSkinRTSettings.shallowColor.g, m_BlurSkinRTSettings.shallowColor.b));
                // Vector3 SSSFC = Vector3.Normalize(new Vector3(m_BlurSkinRTSettings.midColor.r, m_BlurSkinRTSettings.midColor.g, m_BlurSkinRTSettings.midColor.b));
                // SeparableSSS.CalculateKernel(ref kernels, 25, SSSC, SSSFC);
                // cmd.SetGlobalVectorArray("_Kernel", kernels);
                // 
                // cmd.Blit(null, m_ShallowSkinTargetHandle.Identifier(), m_BlurSkinRTSettings.blurMaterial, 2);
                // cmd.Blit(null, m_MidSkinTargetHandle.Identifier(), m_BlurSkinRTSettings.blurMaterial, 3);

                cmd.Blit(m_TempTargetHandle.Identifier(), m_CurrentColorTarget.Identifier(), m_BlurSkinRTSettings.blurMaterial, 1);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_ShallowSkinTargetHandle.id);
            cmd.ReleaseTemporaryRT(m_MidSkinTargetHandle.id);
            cmd.ReleaseTemporaryRT(m_DeepSkinTargetHandle.id);
            cmd.ReleaseTemporaryRT(m_TempTargetHandle.id);
        }
    }
}


