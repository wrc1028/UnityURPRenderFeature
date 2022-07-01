using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpacePlanarReflectionFeature : ScriptableRendererFeature
{
    [System.Serializable]
    internal class ScreenSpacePlanarReflectionSettings
    {
        internal enum TextureSize { full = 1, half = 2, quarter = 4, }
        [SerializeField] internal ComputeShader computeShader;
        
        [Tooltip("世界空间水面高度")]
        [SerializeField] internal float waterHeight;
        [SerializeField] internal TextureSize textureSize = TextureSize.full;
        [Tooltip("边缘拉伸强度")]
        [Range(0.0f, 100.0f)]
        [SerializeField] internal float stretchIntensity = 4.5f;
        [Tooltip("边缘拉伸阈值")]
        [Range(0.0f, 0.5f)]
        [SerializeField] internal float stretchThreshold = 0.2f;
        [Tooltip("边缘过度")]
        [Range(0.0f, 1.0f)]
        [SerializeField] internal float fadeAdjust = 0.95f;
    }
    private SSPRRenderPass ssprPass;
    [SerializeField] private RenderPassEvent m_PassEvent = RenderPassEvent.AfterRenderingSkybox;
    [SerializeField] private ScreenSpacePlanarReflectionSettings m_settings = new ScreenSpacePlanarReflectionSettings();
    public override void Create()
    {
        ssprPass = new SSPRRenderPass(m_settings);
    }
    private bool IsSupportSSPR(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        return SystemInfo.supportsComputeShaders && 
            (renderingData.cameraData.requiresDepthTexture  || renderer.cameraDepthTarget != RenderTargetHandle.CameraTarget.Identifier()) && 
            SystemInfo.graphicsDeviceType != GraphicsDeviceType.OpenGLES2 && SystemInfo.graphicsDeviceType != GraphicsDeviceType.OpenGLES3;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!IsSupportSSPR(renderer, ref renderingData) || m_settings.computeShader == null) return;
        renderer.EnqueuePass(ssprPass);
    }

    // ================= Render Pass =================
    class SSPRRenderPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "ScreenSpacePlanarReflection";
        private ProfilingSampler m_ProfilerSampler = new ProfilingSampler(k_ProfilerTag);
        private const string k_SSPRParam1Id = "_SSPRParam1";
        private const string k_SSPRParam2Id = "_SSPRParam2";
        private const string k_SSPRBuffer = "_SSPRBuffer";
        private const string k_SSPRTextureResult = "_SSPRTextureResult";
#if UNITY_IOS
        private ComputeBuffer m_SSPRBuffer;
#else 
        private RenderTextureDescriptor m_SSPRTextureResultDescriptor;
#endif
        private RenderTextureDescriptor m_SSPRTextureBufferDescriptor;
        
        private RenderTargetHandle m_SSPRTextureResultHandle;
        private RenderTargetHandle m_SSPRTextureBufferHandle;
        internal class DispatchDatas
        {
            public int width;
            public int height;
            public Vector4 param01;
            public Vector4 param02;
            
            public int ClearKernelHandle;
            public int SSPRKernelHandle;
            public int FillHoleKernelHandle;

            public int threadGroupsX;
            public int threadGroupsY;
        }
        private DispatchDatas m_DispatchDatas;
        private ScreenSpacePlanarReflectionSettings m_Settings;
        private ScreenSpacePlanarReflectionVolume m_SSPRVolume;
        public SSPRRenderPass(ScreenSpacePlanarReflectionSettings settings)
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
            m_Settings = settings;
            m_DispatchDatas = new DispatchDatas();
            if (m_Settings.computeShader != null)
            {
                m_DispatchDatas.ClearKernelHandle = m_Settings.computeShader.FindKernel("Clear");
                m_DispatchDatas.SSPRKernelHandle = m_Settings.computeShader.FindKernel("SSPR");
                m_DispatchDatas.FillHoleKernelHandle = m_Settings.computeShader.FindKernel("FillHole");
            }
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            SetSSPRDispatchDatas(renderingData, ref m_DispatchDatas);
            m_SSPRVolume = VolumeManager.instance.stack.GetComponent<ScreenSpacePlanarReflectionVolume>();
            if (m_SSPRVolume != null)
            {
                m_DispatchDatas.param01.z = m_SSPRVolume.waterHeight.value;
            }
            int width = (int)m_DispatchDatas.param01.x;
            int height = (int)m_DispatchDatas.param01.y;
#if UNITY_IOS
            m_SSPRBuffer = new ComputeBuffer(width * height, sizeof(uint), ComputeBufferType.Default);
#else
            m_SSPRTextureBufferDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RInt);
            m_SSPRTextureBufferDescriptor.enableRandomWrite = true;
#endif
            m_SSPRTextureResultDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
            m_SSPRTextureResultDescriptor.enableRandomWrite = true;

            m_SSPRTextureBufferHandle.Init(k_SSPRBuffer);
            m_SSPRTextureResultHandle.Init(k_SSPRTextureResult);

            cmd.GetTemporaryRT(m_SSPRTextureBufferHandle.id, m_SSPRTextureBufferDescriptor, FilterMode.Point);
            cmd.GetTemporaryRT(m_SSPRTextureResultHandle.id, m_SSPRTextureResultDescriptor, FilterMode.Bilinear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_Settings.computeShader == null) return;
            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilerSampler))
            {
                cmd.SetComputeVectorParam(m_Settings.computeShader, k_SSPRParam1Id, m_DispatchDatas.param01);
                cmd.SetComputeVectorParam(m_Settings.computeShader, k_SSPRParam2Id, m_DispatchDatas.param02);
                // Clear
#if UNITY_IOS
                cmd.SetComputeBufferParam(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, k_SSPRBuffer, m_SSPRBuffer); 
#else
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_SSPRTextureBufferHandle.id, m_SSPRTextureBufferHandle.Identifier());
#endif
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_SSPRTextureResultHandle.id, m_SSPRTextureResultHandle.Identifier());
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);
                // SSPR
#if UNITY_IOS
                cmd.SetComputeBufferParam(m_Settings.computeShader, m_DispatchDatas.SSPRKernelHandle, k_SSPRBuffer, m_SSPRBuffer); 
#else
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.SSPRKernelHandle, m_SSPRTextureBufferHandle.id, m_SSPRTextureBufferHandle.Identifier());
#endif
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.SSPRKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);
                // FillHole
#if UNITY_IOS
                cmd.SetComputeBufferParam(m_Settings.computeShader, m_DispatchDatas.FillHoleKernelHandle, k_SSPRBuffer, m_SSPRBuffer); 
#else
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.FillHoleKernelHandle, m_SSPRTextureBufferHandle.id, m_SSPRTextureBufferHandle.Identifier());
#endif
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.FillHoleKernelHandle, m_SSPRTextureResultHandle.id, m_SSPRTextureResultHandle.Identifier());
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.FillHoleKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
#if UNITY_IOS
            m_SSPRBuffer.Release();
#else
            cmd.ReleaseTemporaryRT(m_SSPRTextureBufferHandle.id);
#endif
            cmd.ReleaseTemporaryRT(m_SSPRTextureResultHandle.id);
        }
        // 设置SSPR渲染所需要的的数据
        private void SetSSPRDispatchDatas(RenderingData renderingData, ref DispatchDatas data)
        {
            int width = renderingData.cameraData.cameraTargetDescriptor.width;
            int height = renderingData.cameraData.cameraTargetDescriptor.height;
            data.param01.x = width / (int)m_Settings.textureSize;
            data.param01.y = height / (int)m_Settings.textureSize;
            data.param01.z = m_Settings.waterHeight;
            data.param01.w = (float)m_Settings.textureSize; // TODO: 替换成两边模糊

            data.param02.x = m_Settings.stretchIntensity;
            data.param02.y = m_Settings.stretchThreshold;
            Camera camera = renderingData.cameraData.camera;
            float cameraDirX = camera.transform.eulerAngles.x;
            cameraDirX = cameraDirX > 180 ? cameraDirX - 360 : cameraDirX;
            cameraDirX *= 0.00001f;
            data.param02.z = cameraDirX;
            data.param02.w = m_Settings.fadeAdjust;
            
            data.threadGroupsX = Mathf.CeilToInt(data.param01.x / 8f);
            data.threadGroupsY = Mathf.CeilToInt(data.param01.y / 8f);
        }
    }
}


