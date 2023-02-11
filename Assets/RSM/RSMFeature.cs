using UnityEngine;
using UnityEngine.Rendering.Universal;

public class RSMFeature: ScriptableRendererFeature
{
    [System.Serializable]
    public class PassSettings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

        [Range(1, 16)] public int downsample = 8;

        public int size { get { return 2048 / downsample; } }
    }

    RSMPass pass;
    RSMPassFlux passFlux;
    public PassSettings passSettings = new();

    // Gets called every time serialization happens.
    // Gets called when you enable/disable the renderer feature.
    // Gets called when you change a property in the inspector of the renderer feature.
    public override void Create()
    {
        // Pass the settings as a parameter to the constructor of the pass.
        pass = new RSMPass(passSettings);
        passFlux = new RSMPassFlux(passSettings);

    }

    // Injects one or multiple render passes in the renderer.
    // Gets called when setting up the renderer, once per-camera.
    // Gets called every frame, once per-camera.
    // Will not be called if the renderer feature is disabled in the renderer inspector.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Here you can queue up multiple passes after each other.
        renderer.EnqueuePass(pass);
        renderer.EnqueuePass(passFlux);
    }

}