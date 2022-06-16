using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpacePlanarReflection : ScriptableRendererFeature
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
        [Range(0.0f, 20.0f)]
        [SerializeField] internal float stretchIntensity = 4.5f;
        [Tooltip("边缘拉伸阈值")]
        [Range(0.0f, 0.5f)]
        [SerializeField] internal float stretchThreshold = 0.2f;
        [Tooltip("边缘过度")]
        [Range(0.0f, 1.0f)]
        [SerializeField] internal float fadeAdjust = 0.95f;
    }
    private SSPRRenderPass ssprPass;
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
        private const string k_ViewProjectionMatrixId = "_ViewProjectionMatrix";
        private const string k_InverseViewProjectionMatrix = "_InverseViewProjectionMatrix";
        private const string k_SSPRTextureBuffer = "_SSPRTextureBuffer";
        private const string k_SSPRTextureReuslt = "_SSPRTextureResult";
        // private readonly static int s_SSPRTextureBlurReusltId = Shader.PropertyToID("_SSPRTextureBlurReuslt");
        private RenderTextureDescriptor m_SSPRTextureReusltDescriptor;
        private RenderTextureDescriptor m_SSPRTextureBufferDescriptor;
        
        private RenderTargetHandle m_SSPRTextureResultHandle;
        private RenderTargetHandle m_SSPRTextureBufferHandle;
        internal class DispatchDatas
        {
            public int width;
            public int height;
            public Vector4 param01;
            public Vector4 param02;
            public Matrix4x4 viewProjectionMatrix;
            public Matrix4x4 inverseViewProjectionMatrix;
            
            public int ClearKernelHandle;
            public int SSPRKernelHandle;
            public int FillHoleKernelHandle;

            public int threadGroupsX;
            public int threadGroupsY;
        }
        private DispatchDatas m_DispatchDatas;
        private ScreenSpacePlanarReflectionSettings m_Settings;
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
            int width = (int)m_DispatchDatas.param01.x;
            int height = (int)m_DispatchDatas.param01.y;
            m_SSPRTextureBufferDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RInt);
            m_SSPRTextureBufferDescriptor.enableRandomWrite = true;
            m_SSPRTextureReusltDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
            m_SSPRTextureReusltDescriptor.enableRandomWrite = true;

            m_SSPRTextureBufferHandle.Init(k_SSPRTextureBuffer);
            m_SSPRTextureResultHandle.Init(k_SSPRTextureReuslt);

            cmd.GetTemporaryRT(m_SSPRTextureBufferHandle.id, m_SSPRTextureBufferDescriptor, FilterMode.Point);
            cmd.GetTemporaryRT(m_SSPRTextureResultHandle.id, m_SSPRTextureReusltDescriptor, FilterMode.Bilinear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_Settings.computeShader == null) return;
            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilerSampler))
            {
                cmd.SetComputeVectorParam(m_Settings.computeShader, k_SSPRParam1Id, m_DispatchDatas.param01);
                cmd.SetComputeVectorParam(m_Settings.computeShader, k_SSPRParam2Id, m_DispatchDatas.param02);
                cmd.SetComputeMatrixParam(m_Settings.computeShader, k_ViewProjectionMatrixId, m_DispatchDatas.viewProjectionMatrix);
                cmd.SetComputeMatrixParam(m_Settings.computeShader, k_InverseViewProjectionMatrix, m_DispatchDatas.inverseViewProjectionMatrix);

                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_SSPRTextureBufferHandle.id, m_SSPRTextureBufferHandle.Identifier());
                cmd.SetComputeTextureParam(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_SSPRTextureResultHandle.id, m_SSPRTextureResultHandle.Identifier());
                cmd.DispatchCompute(m_Settings.computeShader, m_DispatchDatas.ClearKernelHandle, m_DispatchDatas.threadGroupsX, m_DispatchDatas.threadGroupsY, 1);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_SSPRTextureBufferHandle.id);
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

            Matrix4x4 viewProjectionMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true) * camera.worldToCameraMatrix;
            data.viewProjectionMatrix = viewProjectionMatrix;
            data.inverseViewProjectionMatrix = viewProjectionMatrix.inverse;
            
            data.threadGroupsX = Mathf.CeilToInt(data.param01.x / 8f);
            data.threadGroupsY = Mathf.CeilToInt(data.param01.y / 8f);
        }
    }
}


