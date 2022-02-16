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
        // 获得当前用于后处理 Shader 的参数ID
        private static readonly int MainTexId = Shader.PropertyToID("_MainTex");
        private static readonly int TempTargetId = Shader.PropertyToID("_TempTargetZoomBlur");
        private static readonly int FocusPowerId = Shader.PropertyToID("_FocusPower");
        private static readonly int FocusDetailId = Shader.PropertyToID("_FocusDetail");
        private static readonly int FocusScreenPositonId = Shader.PropertyToID("_FocusScreenPositon");
        private static readonly int ReferenceResolutionXId = Shader.PropertyToID("_ReferenceResolutionX");
        // 成员变量
        private ZoomBlur zoomBlur;
        private Material zoomBlurMat;
        private RenderTargetIdentifier currentTarget;

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
            this.currentTarget = currentTarget;
        }
        // public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        // {
        // }

        /// <summary>
        /// 具体的后处理的执行规则
        /// </summary>
        /// <param name="context">定义自定义渲染管道使用的状态和图形命令</param>
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
            if (zoomBlur == null || !zoomBlur.IsActive()) return;
            // 2、从命令缓存池中获取一个gl命令缓存(CommandBuffer), 收集一系列GL指令, 用于执行
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
            var source = currentTarget; // ???
            int destination = TempTargetId; // ???

            // 获得渲染相机的分辨率
            int width = cameraData.camera.scaledPixelWidth;
            int height = cameraData.camera.scaledPixelHeight;

            // 对渲染材质的值进行设置
            zoomBlurMat.SetFloat(FocusDetailId, zoomBlur.focusDetail.value);
            zoomBlurMat.SetInt(FocusDetailId, zoomBlur.focusDetail.value);
            zoomBlurMat.SetVector(FocusScreenPositonId, zoomBlur.focusScreenPositon.value);
            zoomBlurMat.SetInt(ReferenceResolutionXId, zoomBlur.referenceResolutionX.value);
            
            int shaderPass = 0;

            // 将当前Camera渲染的颜色结果, 当成_MainTex属性传入
            buffer.SetGlobalTexture(MainTexId, source);
            // 在 CommandBuffer 中获得一张临时的RenderTexture
            buffer.GetTemporaryRT(destination, width, height, 0, FilterMode.Point, RenderTextureFormat.Default);
            // 因为当前渲染的结果要用于下一次渲染, 也就是说下一次渲染要从source指定的位置获取数据, 所以要以要将当次渲染结果输入到source指定的缓存地方
            buffer.Blit(source, destination);
            buffer.Blit(destination, source, zoomBlurMat, shaderPass);
        }   

        // public override void OnCameraCleanup(CommandBuffer cmd)
        // {
        // }
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
        // 初始化当前Pass, 将当前摄像机的颜色缓存标识发送到RenderPass, 表示用当前相机颜色缓存的内容进行渲染
        zoomBlurPass.Setup(renderer.cameraColorTarget);
        // 将当前Pass添加到渲染队列中(renderer)
        renderer.EnqueuePass(zoomBlurPass);
    }
}


