using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// 负责把这个RenderPass加到Renderer里面
public class CustomRendererFeature : ScriptableRendererFeature
{
    // 实际负责渲染逻辑工作的类
    class CustomRenderPass : ScriptableRenderPass
    {
        // 渲染之前, Renderer调用此方法, 配置渲染目标及清除状态, 并创建临时渲染目标纹理
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // 核心方法, 定义渲染执行规则: 渲染逻辑、设置渲染状态、绘制渲染器或绘制程序网格、调度计算等等 
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
        }

        // 完成渲染相机后调用, 释放通过此过程创建的资源
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// 初始化Feature的资源
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


