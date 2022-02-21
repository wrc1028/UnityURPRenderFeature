using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// 负责把这个RenderPass加到Renderer里面
public class CustomRendererFeature : ScriptableRendererFeature
{
    // 实际负责渲染逻辑工作的类
    class CustomRenderPass : ScriptableRenderPass
    {
        // This struct contains all the information required to create a RenderTexture.
        // 一个描述如何创建RenderTexture的结构体
        private RenderTextureDescriptor m_RTDescriptor;
        // RenderTargetIdentifier和RenderTargetHandle都在CommandBuffer内对RenderTarget进行标识(描述)
        // RenderTargetHandle只是一个包装类, 用于将着色器属性id映射到RenderTargetIdentifier.
        private RenderTargetIdentifier m_RTIdentifier;
        private RenderTargetHandle m_RTHandle;
        // 可以通过当前这个方法重新定向渲染目标, 但是只在当前Pass生效
        // 因为下一个运行的Pass只会从它所配置的地方获取属性以和设置渲染目标
        // 当前参数由当前渲染流水线中的Renderer设置
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            
        }
        // 渲染之前, Renderer调用此方法, 配置渲染目标及清除状态, 并创建临时渲染目标纹理
        // 如果渲染过程未重写这个方法，则该渲染过程将渲染到激活状态下 Camera 的渲染目标
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // 核心方法, 定义渲染执行规则: 渲染逻辑、设置渲染状态、绘制渲染器或绘制程序网格、调度计算等等 
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
        }

        // 用于释放通过此过程创建的分配资源。完成渲染相机后调用。就可以使用此回调释放此渲染过程创建的所有资源。
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <summary>
    /// 初始化Pass资源
    /// </summary>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // 在Renderer中插入一个或多个Pass
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


