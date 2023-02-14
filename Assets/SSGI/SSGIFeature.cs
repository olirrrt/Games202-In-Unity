using UnityEngine;
using UnityEngine.Rendering.Universal;

public class SSGIFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class PassSettings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

        [Range(0, 250)] public int RayMarchSampleNum = 50;
        [Range(0, 10)] public float RayMarchStep = 0.5f;

        [Range(0, 1000)] public float maxRayMarchLength = 100;

        [Range(1, 100)] public int IndirectLightSampleNum = 10;
    }

    SSGIPass pass;
    public PassSettings passSettings = new();

    // Gets called every time serialization happens.
    // Gets called when you enable/disable the renderer feature.
    // Gets called when you change a property in the inspector of the renderer feature.
    public override void Create()
    {
        // Pass the settings as a parameter to the constructor of the pass.
        pass = new SSGIPass(passSettings);
    }

    // Injects one or multiple render passes in the renderer.
    // Gets called when setting up the renderer, once per-camera.
    // Gets called every frame, once per-camera.
    // Will not be called if the renderer feature is disabled in the renderer inspector.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Here you can queue up multiple passes after each other.
        renderer.EnqueuePass(pass);
    }

}