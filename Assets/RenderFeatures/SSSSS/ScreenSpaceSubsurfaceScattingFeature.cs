using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceSubsurfaceScattingFeature : ScriptableRendererFeature
{
    [SerializeField] private RenderPassEvent m_Event = RenderPassEvent.BeforeRenderingPostProcessing;
    [System.Serializable]
    internal class ScreenSpaceSubsurfaceScattingSettings
    {
        [SerializeField] internal LayerMask skinSSSLayerMask = 1 << 31;
        [SerializeField] internal Material diffuseMaterial;
        [SerializeField] internal Material blendMaterial;
    }
    private ScreenSpaceSubsurfaceScattingSettings m_Settings = new ScreenSpaceSubsurfaceScattingSettings();


    private ScreenSpaceSubsurfaceScattingPass m_SSSSSPass;

    private RenderSkinPass m_RenderSkinPass;

    public override void Create()
    {
        // m_SSSSSPass = new ScreenSpaceSubsurfaceScattingPass(m_Event, m_Settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // m_SSSSSPass.Setup(renderer.cameraColorTarget);
        // renderer.EnqueuePass(m_SSSSSPass);
    }
    
    class RenderSkinPass : ScriptableRenderPass
    {
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {

        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {

        }
    }

    class ScreenSpaceSubsurfaceScattingPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "Render Skin Object";
        private ProfilingSampler m_ProfilingSampler;
        private ScreenSpaceSubsurfaceScattingSettings m_Settings;
        // 先保存之前的渲染目标
        private RenderTargetIdentifier m_CurrentColorTarget;
        private RenderTargetIdentifier m_CurrentDepthTarget;
        // 保存皮肤漫反射渲染结果
        private RenderTargetHandle m_SkinColorTargetHandle;
        private RenderTargetHandle m_SkinDepthTargetHandle;
        private RenderTextureDescriptor m_SkinColorDescriptor;
        private RenderTextureDescriptor m_SkinDepthDescriptor;
        // 渲染设置
        private FilteringSettings m_FilteringSettings;
        private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();

        public ScreenSpaceSubsurfaceScattingPass(RenderPassEvent renderPassEvent, ScreenSpaceSubsurfaceScattingSettings settings)
        {
            m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);
            this.renderPassEvent = renderPassEvent;
            this.m_Settings = settings;

            m_FilteringSettings = new FilteringSettings(RenderQueueRange.opaque, m_Settings.skinSSSLayerMask);

            m_ShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));
            m_ShaderTagIdList.Add(new ShaderTagId("LightweightForward"));
        }
        public void Setup(RenderTargetIdentifier currentColorTarget)
        {
            m_CurrentColorTarget = currentColorTarget;
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_SkinColorTargetHandle.Init("_SkinColorTexture");
            m_SkinDepthTargetHandle.Init("_SKinDepthTexture");
            int width = renderingData.cameraData.cameraTargetDescriptor.width;
            int height = renderingData.cameraData.cameraTargetDescriptor.height;
            m_SkinColorDescriptor = new RenderTextureDescriptor(width, height, renderingData.cameraData.cameraTargetDescriptor.colorFormat);
            m_SkinDepthDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.Depth, renderingData.cameraData.cameraTargetDescriptor.depthBufferBits);
            cmd.GetTemporaryRT(m_SkinColorTargetHandle.id, m_SkinColorDescriptor);
            cmd.GetTemporaryRT(m_SkinDepthTargetHandle.id, m_SkinDepthDescriptor);
            ConfigureTarget(m_SkinColorTargetHandle.id, m_SkinDepthTargetHandle.id);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;
            DrawingSettings drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);
            drawingSettings.overrideMaterial = m_Settings.diffuseMaterial;
            drawingSettings.overrideMaterialPassIndex = 0;
            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
                
                // cmd.SetGlobalTexture("_DiffuseTex", m_SkinColorTargetHandle.id);
                // cmd.Blit(m_CurrentColorTarget, m_CurrentColorTarget, m_Settings.blendMaterial);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_SkinColorTargetHandle.id);
            cmd.ReleaseTemporaryRT(m_SkinDepthTargetHandle.id);
        }
    }

}


