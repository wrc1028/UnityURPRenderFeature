using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionFeature : ScriptableRendererFeature
{
    [System.Serializable]
    internal class ScreenSpaceReflectionSettings
    {
        internal enum TextureSize { full = 1, half = 2, quarter = 4, Eighth = 8}
        [SerializeField] internal ComputeShader computeShader;
        
        [Tooltip("世界空间水面高度")]
        [SerializeField] internal float waterHeight;
        [SerializeField] internal TextureSize textureSize = TextureSize.full;
    }

    private ScreenSpaceReflectionPass m_ScriptablePass;
    [SerializeField] private RenderPassEvent m_PassEvent = RenderPassEvent.AfterRenderingSkybox;
    [SerializeField] private ScreenSpaceReflectionSettings m_Settings = new ScreenSpaceReflectionSettings();
    private bool IsSupportSSPR(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        return SystemInfo.supportsComputeShaders && 
            (renderingData.cameraData.requiresDepthTexture  || renderer.cameraDepthTarget != RenderTargetHandle.CameraTarget.Identifier()) && 
            SystemInfo.graphicsDeviceType != GraphicsDeviceType.OpenGLES2 && SystemInfo.graphicsDeviceType != GraphicsDeviceType.OpenGLES3;
    }
    public override void Create()
    {
        m_ScriptablePass = new ScreenSpaceReflectionPass(m_Settings, m_PassEvent);
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!IsSupportSSPR(renderer, ref renderingData) || m_Settings.computeShader == null) return;
        renderer.EnqueuePass(m_ScriptablePass);
    }
    
    /// <summary>
    /// render pass
    /// </summary>
    class ScreenSpaceReflectionPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "ScreenSpaceReflection";
        private ProfilingSampler m_ProfilerSampler = new ProfilingSampler(k_ProfilerTag);
        private const string k_SSPRParamId = "_SSRParam";
        private const string k_SSRBuffer = "_SSRBuffer";
        private const string k_RayDepthTexture = "_RayDepthTexture";
        private RenderTextureDescriptor m_SSPRTextureBufferDescriptor;
        private RenderTextureDescriptor m_RayDepthTextureDescriptor;
        private RenderTargetHandle m_SSRTextureBufferHandle;
        private RenderTargetHandle m_RayDepthTextureHandle;

        internal class DispatchDatas
        {
            public int width;
            public int height;
            public Vector4 param;
            
            public int ClearKernelHandle;
            public int SSRKernelHandle;
            public int DepthKernelHandle;

            public int threadGroupsX;
            public int threadGroupsY;
        }
        private DispatchDatas m_DispatchDatas;
        private ScreenSpaceReflectionSettings m_Settings;
        public ScreenSpaceReflectionPass(ScreenSpaceReflectionSettings settings, RenderPassEvent passEvent)
        {
            renderPassEvent = passEvent;
            m_Settings = settings;
            m_DispatchDatas = new DispatchDatas();
            if (m_Settings.computeShader != null)
            {
                m_DispatchDatas.ClearKernelHandle = m_Settings.computeShader.FindKernel("Clear");
                m_DispatchDatas.SSRKernelHandle = m_Settings.computeShader.FindKernel("SSR");
                m_DispatchDatas.DepthKernelHandle = m_Settings.computeShader.FindKernel("Depth");
            }
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            SetSSRDispatchDatas(renderingData, ref m_DispatchDatas);
            int width = (int)m_DispatchDatas.param.x;
            int height = (int)m_DispatchDatas.param.y;
            m_RayDepthTextureDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.R16);
            m_RayDepthTextureDescriptor.enableRandomWrite = true;

            m_SSPRTextureBufferDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RInt);
            m_SSPRTextureBufferDescriptor.enableRandomWrite = true;
            
            m_SSRTextureBufferHandle.Init(k_SSRBuffer);
            m_RayDepthTextureHandle.Init(k_RayDepthTexture);

            cmd.GetTemporaryRT(m_SSRTextureBufferHandle.id, m_SSPRTextureBufferDescriptor, FilterMode.Point);
            cmd.GetTemporaryRT(m_RayDepthTextureHandle.id, m_RayDepthTextureDescriptor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_Settings.computeShader == null) return;
            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilerSampler))
            {
                cmd.SetComputeVectorParam(m_Settings.computeShader, k_SSPRParamId, m_DispatchDatas.param);
                // clear
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_SSRTextureBufferHandle.id, m_SSRTextureBufferHandle.Identifier());
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);
                // ssr
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.SSRKernelHandle, m_SSRTextureBufferHandle.id, m_SSRTextureBufferHandle.Identifier());
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.SSRKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);
                // depth
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.DepthKernelHandle, m_SSRTextureBufferHandle.id, m_SSRTextureBufferHandle.Identifier());
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.DepthKernelHandle, m_RayDepthTextureHandle.id, m_RayDepthTextureHandle.Identifier());
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.DepthKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);

            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_RayDepthTextureHandle.id);
            cmd.ReleaseTemporaryRT(m_SSRTextureBufferHandle.id);
        }
        private void SetSSRDispatchDatas(RenderingData renderingData, ref DispatchDatas data)
        {
            int width = renderingData.cameraData.cameraTargetDescriptor.width;
            int height = renderingData.cameraData.cameraTargetDescriptor.height;
            data.param.x = width / (int)m_Settings.textureSize;
            data.param.y = height / (int)m_Settings.textureSize;
            data.param.z = m_Settings.waterHeight;
            data.param.w = (float)m_Settings.textureSize;
            
            data.threadGroupsX = Mathf.CeilToInt(data.param.x / 8f);
            data.threadGroupsY = Mathf.CeilToInt(data.param.y / 8f);
        }
    }
}


