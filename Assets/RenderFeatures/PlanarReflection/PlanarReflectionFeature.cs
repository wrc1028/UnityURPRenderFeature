using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PlanarReflectionFeature : ScriptableRendererFeature
{
    [System.Serializable]
    internal class PlanarReflectionSettings
    {
        internal enum TextureSize { full = 1, half = 2, quarter = 4, }
        [SerializeField] internal LayerMask layerMask = -1;
        [SerializeField] internal TextureSize textureSize = TextureSize.full;
    }
    [SerializeField] private PlanarReflectionSettings m_Settings = new PlanarReflectionSettings();
    
    private PlanarReflectionPass m_ScriptablePass;
    public override void Create()
    {
        m_ScriptablePass = new PlanarReflectionPass(m_Settings);

        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    

    // Render pass
    private class PlanarReflectionPass : ScriptableRenderPass
    {
        private PlanarReflectionSettings m_Settings;
        private Camera m_ReflectionCamera;
        public PlanarReflectionPass(PlanarReflectionSettings settings)
        {
            m_Settings = settings;

        }
         
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
}


