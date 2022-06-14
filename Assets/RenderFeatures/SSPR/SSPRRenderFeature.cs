using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SSPRRenderFeature : ScriptableRendererFeature
{
    class SSPRRenderPass : ScriptableRenderPass
    {
        private SSPRRenderData ssprRenderData;
        private SSPRCSDispatchData ssprCSDispatchData;
        public SSPRRenderPass(RenderPassEvent passEvent)
        {
            renderPassEvent = passEvent;
        }
        public void Setup(SSPRRenderData renderData, SSPRCSDispatchData dispatchData)
        {
            ssprRenderData = renderData;
            ssprCSDispatchData = dispatchData;
        }
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {

        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
    }
    // ========================================================================================================
    public enum TextureSize { full = 1, half = 2, quarter = 4, }
    [System.Serializable]
    public class TextureSetting
    {
        [Tooltip("反射贴图分辨率大小")]
        public TextureSize textureSize = TextureSize.half;
        [Tooltip("边缘拉伸强度")]
        [Range(0.0f, 20.0f)]
        public float stretchIntensity = 4.5f;
        [Tooltip("边缘拉伸阈值")]
        [Range(0.0f, 0.5f)]
        public float stretchThreshold = 0.2f;
        [Tooltip("边缘过度")]
        [Range(0.0f, 1.0f)]
        public float fadeAdjust = 0.95f;
    }
    public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingTransparents;
    [Tooltip("计算着色器")]
    public ComputeShader SSPRCS;
    [Tooltip("世界空间水面高度")]
    public float waterHeight;
    public TextureSetting textureSetting;

    private SSPRRenderPass m_ScriptablePass;

    // 用于SSPR渲染的数据
    public class SSPRRenderData
    {
        public Vector4 SSPRParam1;
        public Vector4 SSPRParam2;
        public Matrix4x4 viewProjectionMatrix;
        public Matrix4x4 inverseViewProjectionMatrix;
        public ComputeShader SSPRCS;
    }
    private SSPRRenderData ssprRenderData;
    // 用于执行SSPRCS的数据
    public class SSPRCSDispatchData
    {
        public int ClearKernelHandle;
        public int SSPRKernelHandle;
        public int FillHoleKernelHandle;
        public uint[] BufferDatas;
        public RenderTextureDescriptor SSPRResult;
        public int threadGroupsX;
        public int threadGroupsY;
    }
    private SSPRCSDispatchData ssprCSDispatchData;
    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new SSPRRenderPass(passEvent);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (SSPRCS == null) return;
        ssprRenderData = new SSPRRenderData();
        SetSSPRRenderData(renderingData, ref ssprRenderData);
        ssprCSDispatchData = new SSPRCSDispatchData();
        SetSSPRCSDispatchData(ssprRenderData, ref ssprCSDispatchData);
        m_ScriptablePass.Setup(ssprRenderData, ssprCSDispatchData);
        renderer.EnqueuePass(m_ScriptablePass);
    }

    // 设置SSPR渲染所需要的的数据
    private void SetSSPRRenderData(RenderingData renderingData, ref SSPRRenderData data)
    {
        data.SSPRCS = SSPRCS;
        data.SSPRParam1.x = renderingData.cameraData.cameraTargetDescriptor.width;
        data.SSPRParam1.y = renderingData.cameraData.cameraTargetDescriptor.height;
        data.SSPRParam1.z = waterHeight;
        data.SSPRParam1.w = (float)textureSetting.textureSize;

        data.SSPRParam2.x = textureSetting.stretchIntensity;
        data.SSPRParam2.y = textureSetting.stretchThreshold;
        Camera camera = renderingData.cameraData.camera;
        float cameraDirX = camera.transform.eulerAngles.x;
        cameraDirX = cameraDirX > 180 ? cameraDirX - 360 : cameraDirX;
        cameraDirX *= 0.00001f;
        data.SSPRParam2.z = cameraDirX;
        data.SSPRParam2.w = textureSetting.fadeAdjust;

        Matrix4x4 viewProjectionMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * camera.worldToCameraMatrix;
        data.viewProjectionMatrix = viewProjectionMatrix;
        data.inverseViewProjectionMatrix = viewProjectionMatrix.inverse;
    }

    public void SetSSPRCSDispatchData(SSPRRenderData renderData, ref SSPRCSDispatchData dispatchData)
    {
        dispatchData.ClearKernelHandle = renderData.SSPRCS.FindKernel("Clear");
        dispatchData.SSPRKernelHandle = renderData.SSPRCS.FindKernel("SSPR");
        dispatchData.FillHoleKernelHandle = renderData.SSPRCS.FindKernel("FillHole");
        
        int width = (int)(renderData.SSPRParam1.x / renderData.SSPRParam1.w);
        int height = (int)(renderData.SSPRParam1.y / renderData.SSPRParam1.w);
        dispatchData.BufferDatas = new uint[width * height];

        dispatchData.SSPRResult = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
        dispatchData.SSPRResult.enableRandomWrite = true;

        dispatchData.threadGroupsX = Mathf.CeilToInt(width / 8);
        dispatchData.threadGroupsY = Mathf.CeilToInt(height / 8);
    }
}


