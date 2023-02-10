using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class RSMPassFlux : ScriptableRenderPass
{
    const string ProfilerTag = "RSM Pass2";

    RSMFeature.PassSettings passSettings;

    RenderTargetIdentifier colorBuffer, myBuffer;
    int myBufferID = Shader.PropertyToID("RSMFluxBuffer");

    Material material;

    List<ShaderTagId> shaderTags = new() { new ShaderTagId("UniversalForward"), new ShaderTagId("SRPDefaultUnlit") };
    DrawingSettings drawingSettings;
    FilteringSettings filteringSettings = new(RenderQueueRange.opaque);

    Matrix4x4 mainLightMat;
    int size = 2048;
    public RSMPassFlux(RSMFeature.PassSettings passSettings)
    {
        this.passSettings = passSettings;
        this.size /= passSettings.downsample;
        renderPassEvent = passSettings.renderPassEvent;


        if (material == null) material = CoreUtils.CreateEngineMaterial("Custom/RSMHandle-Flux");

    }


    // 初始化相机参数
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // Grab the camera target descriptor. We will use this when creating a temporary render texture.
        RenderTextureDescriptor defalut = renderingData.cameraData.cameraTargetDescriptor;

        // Grab the color buffer from the renderer camera color target.
        colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;

        // 创建 temporary rt, 名字为myBufferID，指定render target
        RenderTextureDescriptor descriptor = new() { width = size, height = size, colorFormat = RenderTextureFormat.ARGB32, msaaSamples = 1, dimension = TextureDimension.Tex2D };
        cmd.GetTemporaryRT(myBufferID, descriptor, FilterMode.Bilinear);
        myBuffer = new RenderTargetIdentifier(myBufferID);


        // 指定渲染到哪里
        ConfigureTarget(myBuffer);
        Configure(cmd, descriptor);
    }


    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // Grab a command buffer. We put the actual execution of the pass inside of a profiling scope.
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, new ProfilingSampler(ProfilerTag)))// buffer name
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            // 指定pass、排序
            drawingSettings = CreateDrawingSettings(shaderTags, ref renderingData, SortingCriteria.CommonOpaque);

            drawingSettings.overrideMaterial = material;
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
            cmd.SetGlobalTexture("_RSMFlux", myBuffer);
        }
        // cmd.ClearRenderTarget(true, true, Color.black);
        // Execute the command buffer and release it.
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    // Called when the camera has finished rendering.
    // Here we release/cleanup any allocated resources that were created by this pass.
    // Gets called for all cameras i na camera stack.
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        if (cmd == null) throw new ArgumentNullException("cmd");

        cmd.ReleaseTemporaryRT(myBufferID);

    }
}