using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpacePlanarReflection : ScriptableRendererFeature
{
    class SSPRRenderPass : ScriptableRenderPass
    {
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    private SSPRRenderPass ssprPass;

    public override void Create()
    {
        ssprPass = new SSPRRenderPass();
        ssprPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(ssprPass);
    }
}


