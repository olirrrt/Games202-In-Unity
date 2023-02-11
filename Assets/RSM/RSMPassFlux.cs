using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class RSMPassFlux : ScriptableRenderPass
{
    const string ProfilerTag = "RSM PrePass2";

    RSMFeature.PassSettings passSettings;

    RenderTargetIdentifier colorBuffer, myBuffer;
    int myBufferID = Shader.PropertyToID("RSMFluxBuffer");

    List<ShaderTagId> shaderTags = new() { new ShaderTagId("RSMFLux") };
    DrawingSettings drawingSettings;
    FilteringSettings filteringSettings = new(RenderQueueRange.opaque);

    Matrix4x4 mainLightMat;
    int size;

    public RSMPassFlux(RSMFeature.PassSettings passSettings)
    {
        this.passSettings = passSettings;
        this.size = passSettings.size;
        renderPassEvent = passSettings.renderPassEvent;

    }


    // 初始化相机参数
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {

        // 创建 temporary rt, 名字为myBufferID，指定render target
        var descriptor = new RenderTextureDescriptor(size, size, RenderTextureFormat.ARGB32, 32, 1);
        cmd.GetTemporaryRT(myBufferID, descriptor, FilterMode.Bilinear);
        myBuffer = new RenderTargetIdentifier(myBufferID);
      
        // 指定渲染到哪里
        ConfigureTarget(myBuffer);
        Configure(cmd, descriptor);
    }


    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, new ProfilingSampler(ProfilerTag)))// buffer name
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            // 指定pass、排序
            drawingSettings = CreateDrawingSettings(shaderTags, ref renderingData, SortingCriteria.CommonOpaque);
            cmd.SetGlobalTexture("_RSMFlux", myBuffer);
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
 
        }
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