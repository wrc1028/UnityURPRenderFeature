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
        private readonly static int s_SSPRParam1Id = Shader.PropertyToID("_SSPRParam1");
        private readonly static int s_SSPRParam2Id = Shader.PropertyToID("_SSPRParam2");
        private readonly static int s_ViewProjectionMatrixId = Shader.PropertyToID("_ViewProjectionMatrix");
        private readonly static int s_InverseViewProjectionMatrix = Shader.PropertyToID("_InverseViewProjectionMatrix");
        internal class DispatchDatas
        {
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
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
        // 设置SSPR渲染所需要的的数据
        private void SetSSPRDispatchDatas(RenderingData renderingData, ref DispatchDatas data)
        {
            data.param01.x = renderingData.cameraData.cameraTargetDescriptor.width;
            data.param01.y = renderingData.cameraData.cameraTargetDescriptor.height;
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
        }
    }
}


