using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SSPRRenderFeature : ScriptableRendererFeature
{
    // 用于SSPR渲染的数据
    public class SSPRRenderData
    {
        public int SSPRParam1Id;
        public Vector4 SSPRParam1;
        public int SSPRParam2Id;
        public Vector4 SSPRParam2;
        public int viewProjectionMatrixId;
        public Matrix4x4 viewProjectionMatrix;
        public int inverseViewProjectionMatrixId;
        public Matrix4x4 inverseViewProjectionMatrix;
        public ComputeShader SSPRCS;
    }
    // 用于执行SSPRCS的数据
    public class SSPRCSDispatchData
    {
        public int ClearKernelHandle;
        public int SSPRKernelHandle;
        public int FillHoleKernelHandle;
        public int SSPRRenderBufferId;
        public uint[] SSPRRenderBufferDatas;
        public ComputeBuffer SSPRRenderBuffer;
        public RenderTargetHandle SSPRRenderTexture;
        public RenderTextureDescriptor SSPRRenderTextureDescriptor;
        public RenderTargetHandle SSPRRenderTextureBuffer;
        public RenderTextureDescriptor SSPRRenderTextureBufferDescriptor;
        public int threadGroupsX;
        public int threadGroupsY;
    }
    class SSPRRenderPass : ScriptableRenderPass
    {
        private const string m_ProfilerTag = "SSPlanarReflectionsFeature";
        private ProfilingSampler m_ProfilerSampler = new ProfilingSampler(m_ProfilerTag);

        private float waterHeight;
        private TextureSetting textureSetting;
        private SSPRRenderData ssprRenderData;
        private SSPRCSDispatchData ssprCSDispatchData;
        public SSPRRenderPass(ComputeShader SSPRCS, float waterHeight, TextureSetting textureSetting)
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
            this.waterHeight = waterHeight;
            this.textureSetting = textureSetting;

            ssprRenderData = new SSPRRenderData();
            ssprRenderData.SSPRParam1Id = Shader.PropertyToID("_SSPRParam");
            ssprRenderData.SSPRParam2Id = Shader.PropertyToID("_SSPRParam2");
            ssprRenderData.viewProjectionMatrixId = Shader.PropertyToID("_ViewProjectionMatrix");
            ssprRenderData.inverseViewProjectionMatrixId = Shader.PropertyToID("_InverseViewProjectionMatrix");
            if (SSPRCS != null)
            {
                ssprRenderData.SSPRCS = SSPRCS;
                ssprCSDispatchData = new SSPRCSDispatchData();
                ssprCSDispatchData.ClearKernelHandle = SSPRCS.FindKernel("Clear");
                ssprCSDispatchData.SSPRKernelHandle = SSPRCS.FindKernel("SSPR");
                ssprCSDispatchData.FillHoleKernelHandle = SSPRCS.FindKernel("FillHole");

                ssprCSDispatchData.SSPRRenderBufferId = Shader.PropertyToID("SSPRBuffer");
                ssprCSDispatchData.SSPRRenderTexture.Init("SSPRResult");
                ssprCSDispatchData.SSPRRenderTextureBuffer.Init("SSPRBufferTex");
            }
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            SetSSPRRenderData(renderingData, ref ssprRenderData);
            SetSSPRCSDispatchData(ssprRenderData, ref ssprCSDispatchData);
            cmd.GetTemporaryRT(ssprCSDispatchData.SSPRRenderTexture.id, ssprCSDispatchData.SSPRRenderTextureDescriptor);
            cmd.GetTemporaryRT(ssprCSDispatchData.SSPRRenderTextureBuffer.id, ssprCSDispatchData.SSPRRenderTextureBufferDescriptor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (ssprRenderData.SSPRCS == null) return;
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilerSampler))
            {
                cmd.SetComputeVectorParam(ssprRenderData.SSPRCS, ssprRenderData.SSPRParam1Id, ssprRenderData.SSPRParam1);
                cmd.SetComputeVectorParam(ssprRenderData.SSPRCS, ssprRenderData.SSPRParam2Id, ssprRenderData.SSPRParam2);
                cmd.SetComputeMatrixParam(ssprRenderData.SSPRCS, ssprRenderData.viewProjectionMatrixId, ssprRenderData.viewProjectionMatrix);
                cmd.SetComputeMatrixParam(ssprRenderData.SSPRCS, ssprRenderData.inverseViewProjectionMatrixId, ssprRenderData.inverseViewProjectionMatrix);
                // 清楚贴图
                // cmd.SetComputeBufferParam(ssprRenderData.SSPRCS, ssprCSDispatchData.ClearKernelHandle, ssprCSDispatchData.SSPRRenderBufferId, ssprCSDispatchData.SSPRRenderBuffer);
                cmd.SetComputeTextureParam(ssprRenderData.SSPRCS, ssprCSDispatchData.ClearKernelHandle, ssprCSDispatchData.SSPRRenderTexture.id, ssprCSDispatchData.SSPRRenderTexture.Identifier());
                cmd.SetComputeTextureParam(ssprRenderData.SSPRCS, ssprCSDispatchData.ClearKernelHandle, ssprCSDispatchData.SSPRRenderTextureBuffer.id, ssprCSDispatchData.SSPRRenderTextureBuffer.Identifier());
                cmd.DispatchCompute(ssprRenderData.SSPRCS, ssprCSDispatchData.ClearKernelHandle, ssprCSDispatchData.threadGroupsX, ssprCSDispatchData.threadGroupsY, 1);
                // 计算
                // cmd.SetComputeBufferParam(ssprRenderData.SSPRCS, ssprCSDispatchData.SSPRKernelHandle, ssprCSDispatchData.SSPRRenderBufferId, ssprCSDispatchData.SSPRRenderBuffer);
                // cmd.SetComputeTextureParam(ssprRenderData.SSPRCS, ssprCSDispatchData.SSPRKernelHandle, ssprCSDispatchData.SSPRRenderTexture.id, ssprCSDispatchData.SSPRRenderTexture.Identifier());
                cmd.SetComputeTextureParam(ssprRenderData.SSPRCS, ssprCSDispatchData.SSPRKernelHandle, ssprCSDispatchData.SSPRRenderTextureBuffer.id, ssprCSDispatchData.SSPRRenderTextureBuffer.Identifier());
                cmd.DispatchCompute(ssprRenderData.SSPRCS, ssprCSDispatchData.SSPRKernelHandle, ssprCSDispatchData.threadGroupsX, ssprCSDispatchData.threadGroupsY, 1);
                // 填洞
                // cmd.SetComputeBufferParam(ssprRenderData.SSPRCS, ssprCSDispatchData.FillHoleKernelHandle, ssprCSDispatchData.SSPRRenderBufferId, ssprCSDispatchData.SSPRRenderBuffer);
                cmd.SetComputeTextureParam(ssprRenderData.SSPRCS, ssprCSDispatchData.FillHoleKernelHandle, ssprCSDispatchData.SSPRRenderTextureBuffer.id, ssprCSDispatchData.SSPRRenderTextureBuffer.Identifier());
                cmd.SetComputeTextureParam(ssprRenderData.SSPRCS, ssprCSDispatchData.FillHoleKernelHandle, ssprCSDispatchData.SSPRRenderTexture.id, ssprCSDispatchData.SSPRRenderTexture.Identifier());
                cmd.DispatchCompute(ssprRenderData.SSPRCS, ssprCSDispatchData.FillHoleKernelHandle, ssprCSDispatchData.threadGroupsX, ssprCSDispatchData.threadGroupsY, 1);

                cmd.SetGlobalTexture("_SSReflectionTexture", ssprCSDispatchData.SSPRRenderTexture.Identifier());
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(ssprCSDispatchData.SSPRRenderTexture.id);
            ssprCSDispatchData.SSPRRenderBuffer.Release();
        }
        // 设置SSPR渲染所需要的的数据
        private void SetSSPRRenderData(RenderingData renderingData, ref SSPRRenderData data)
        {
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

            Matrix4x4 viewProjectionMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true) * camera.worldToCameraMatrix;
            data.viewProjectionMatrix = viewProjectionMatrix;
            data.inverseViewProjectionMatrix = viewProjectionMatrix.inverse;
        }
        public void SetSSPRCSDispatchData(SSPRRenderData renderData, ref SSPRCSDispatchData dispatchData)
        {
            
            int width = (int)(renderData.SSPRParam1.x / renderData.SSPRParam1.w);
            int height = (int)(renderData.SSPRParam1.y / renderData.SSPRParam1.w);
            dispatchData.SSPRRenderBufferDatas = new uint[width * height];

            dispatchData.SSPRRenderBuffer = new ComputeBuffer(dispatchData.SSPRRenderBufferDatas.Length, sizeof(uint));
            // dispatchData.SSPRRenderBuffer.SetData(dispatchData.SSPRRenderBufferDatas);

            dispatchData.SSPRRenderTextureDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
            dispatchData.SSPRRenderTextureDescriptor.enableRandomWrite = true;

            dispatchData.SSPRRenderTextureBufferDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RInt);
            dispatchData.SSPRRenderTextureBufferDescriptor.enableRandomWrite = true;

            dispatchData.threadGroupsX = Mathf.CeilToInt(width / 8f);
            dispatchData.threadGroupsY = Mathf.CeilToInt(height / 8f);
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
    [Tooltip("计算着色器")]
    public ComputeShader SSPRCS;
    [Tooltip("世界空间水面高度")]
    public float waterHeight;
    public TextureSetting textureSetting;

    private SSPRRenderPass m_ScriptablePass;

    
    private SSPRRenderData ssprRenderData;
    
    private SSPRCSDispatchData ssprCSDispatchData;
    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new SSPRRenderPass(SSPRCS, waterHeight, textureSetting);
    }

    /// <summary>
    /// 当前平台是否支持SSPR
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    /// <returns></returns>
    private bool IsSupportSSPR(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        return SystemInfo.supportsComputeShaders;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (SSPRCS == null) return;
        // ssprRenderData = new SSPRRenderData();
        // SetSSPRRenderData(renderingData, ref ssprRenderData);
        // ssprCSDispatchData = new SSPRCSDispatchData();
        // SetSSPRCSDispatchData(ssprRenderData, ref ssprCSDispatchData);

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
}


