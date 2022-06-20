using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ZoomBlurRenderFeature : ScriptableRendererFeature
{
    class ZoomBlurRenderPass : ScriptableRenderPass
    {
        // 显示在FrameDebugger的标签
        private static readonly string k_RenderTag = "Render ZoomBlur Effects";
        // 为了提高效率，Unity为着色器属性的每个名称(例如，_MainTex或_Color)都分配一个唯一的整数，在整个游戏中保持不变。使用属性标识符比向所有物质属性函数传递字符串更有效。
        // private static readonly int MainTexId = Shader.PropertyToID("_MainTex");
        private RenderTargetHandle m_MainTexHandle = new RenderTargetHandle();
        private static readonly int FocusPowerId = Shader.PropertyToID("_FocusPower");
        private static readonly int FocusDetailId = Shader.PropertyToID("_FocusDetail");
        private static readonly int FocusScreenPositonId = Shader.PropertyToID("_FocusScreenPositon");
        private static readonly int ReferenceResolutionXId = Shader.PropertyToID("_ReferenceResolutionX");
        private ZoomBlur zoomBlur;
        private ScreenSpacePlanarReflectionVolume screenSpacePlanarReflectionVolume;
        private Material zoomBlurMat;
        // 一个描述RT的结构体
        private RenderTextureDescriptor m_TempTargetDescriptor;
        // 用于创建渲染目标的结构体
        private RenderTargetHandle m_TempTarget;
        private RenderTargetHandle m_CurrentTarget;
        private RenderTargetIdentifier a;
        public ZoomBlurRenderPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            // 获得ZoomBlur的Shader
            Shader zoomBlurShader = Shader.Find("PostEffect/ZoomBlur");
            if (zoomBlurShader == null)
            {
                Debug.LogError("Shader not found!");
                return;
            }
            zoomBlurMat = new Material(zoomBlurShader);
        }

        // 
        public void Setup(in RenderTargetIdentifier currentTarget)
        {
            m_CurrentTarget = new RenderTargetHandle(currentTarget);
        }
        
        private RenderTargetHandle m_CustomRenderTarget = new RenderTargetHandle();
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // m_CustomRenderTarget.Init("_CustomRenderTarget");
            // cmd.GetTemporaryRT(m_CustomRenderTarget.id, cameraTextureDescriptor, FilterMode.Bilinear);
            // cmd.SetRenderTarget(m_CustomRenderTarget.Identifier());
        }

        // public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        // {
        // }

        /// <summary>
        /// 具体的后处理的执行规则
        /// </summary>
        /// <param name="context">自定义渲染管道使用的状态和图形命令</param>
        /// <param name="renderingData">用于最终渲染的渲染数据汇总: 其中包括剔除后的结果、相机参数、灯光数据等等</param>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (zoomBlurMat == null)
            {
                Debug.LogError("Material not created!");
                return;
            }
            // 如果当前后处理没有生效, 返回
            if (!renderingData.cameraData.postProcessEnabled) return;

            // ------处理流程------
            // 1、获得当前优先级最好的Volume组件下指定后处理实例, 获取里面的属性变量来做具体的后处理
            var stack = VolumeManager.instance.stack;
            zoomBlur = stack.GetComponent<ZoomBlur>();
            screenSpacePlanarReflectionVolume = stack.GetComponent<ScreenSpacePlanarReflectionVolume>();
            if (zoomBlur == null || !zoomBlur.IsActive()) return;
            // 2、从命令缓存池中获取一个gl命令缓存(CommandBuffer), 用于收集一系列GL指令, 然后执行
            CommandBuffer zoomBlurBuffer = CommandBufferPool.Get(k_RenderTag);
            // 3、在命令缓存中构建渲染命令
            Render(zoomBlurBuffer, ref renderingData);
            // 4、提交 CommandBuffer 中的GL命令, 进行渲染
            context.ExecuteCommandBuffer(zoomBlurBuffer);
            // 5、清空 CommandBuffer
            CommandBufferPool.Release(zoomBlurBuffer);
        }
        // 实际渲染 CommandBuffer分为: Texutre以及参数
        private void Render(CommandBuffer buffer, ref RenderingData renderingData)
        {
            // 获得相机的渲染数据
            ref CameraData cameraData = ref renderingData.cameraData;
            m_TempTarget.Init("_TempRenderTarget");
            m_MainTexHandle.Init("_MainTex");

            // 获得渲染相机的基本参数
            m_TempTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;

            // 对渲染材质的值进行设置
            zoomBlurMat.SetFloat(FocusPowerId, zoomBlur.focusPower.value);
            zoomBlurMat.SetInt(FocusDetailId, zoomBlur.focusDetail.value);
            zoomBlurMat.SetVector(FocusScreenPositonId, zoomBlur.focusScreenPositon.value);
            zoomBlurMat.SetInt(ReferenceResolutionXId, zoomBlur.referenceResolutionX.value);
            
            int shaderPass = 0;

            // 将当前Camera渲染的颜色结果, 当成_MainTex属性传入
            buffer.SetGlobalTexture(m_MainTexHandle.id, m_CurrentTarget.Identifier());
            // 在 CommandBuffer 中获得一张临时的RenderTexture
            buffer.GetTemporaryRT(m_TempTarget.id, m_TempTargetDescriptor, FilterMode.Point);
            // 因为当前渲染的结果要用于下一次渲染, 也就是说下一次渲染要从source指定的位置获取数据, 所以要以要将当次渲染结果输入到source指定的缓存地方
            buffer.Blit(m_CurrentTarget.Identifier(), m_TempTarget.Identifier());
            buffer.Blit(m_TempTarget.Identifier(), m_CurrentTarget.Identifier(), zoomBlurMat, shaderPass);
        }

        // public override void OnCameraCleanup(CommandBuffer cmd)
        // {
        // }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_CustomRenderTarget.id);
        }
    }

    public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    private ZoomBlurRenderPass zoomBlurPass;

    public override void Create()
    {
        zoomBlurPass = new ZoomBlurRenderPass(renderPassEvent);
    }

    // 在 Renderer 中插入我们自定义的 ZoomBlurPass
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 初始化当前Pass, 将当前摄像机记录颜色缓存的RenderTexture标识发送到RenderPass
        // 表示用当前相机颜色缓存的内容进行渲染
        zoomBlurPass.Setup(renderer.cameraColorTarget);
        // 将当前Pass添加到渲染队列中(renderer)
        renderer.EnqueuePass(zoomBlurPass);
    }
}


