using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class RSMPass : ScriptableRenderPass
{
    const string ProfilerTag = "RSM PrePass";

    RSMFeature.PassSettings passSettings;

    RenderTargetIdentifier colorBuffer, myBuffer;
    readonly int myBufferID = Shader.PropertyToID("RSMDepthBuffer");
    readonly int sizeID = Shader.PropertyToID("_RSMTextureSize");

    Material material;

    List<ShaderTagId> shaderTags = new() { new ShaderTagId("UniversalForward") };
    DrawingSettings drawingSettings;
    FilteringSettings filteringSettings = new(RenderQueueRange.opaque);

    int size;

    public RSMPass(RSMFeature.PassSettings passSettings)
    {
        this.passSettings = passSettings;
        this.size = passSettings.size;
        renderPassEvent = passSettings.renderPassEvent;
        if (material == null) material = CoreUtils.CreateEngineMaterial("Custom/RSMPrePass");
    }


    // 初始化相机参数
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // RenderTextureDescriptor defalut = renderingData.cameraData.cameraTargetDescriptor;

        // 创建 temporary rt, 名字为myBufferID，指定render target
        var descriptor = new RenderTextureDescriptor(size,size, RenderTextureFormat.ARGB32,32,1);
         
        cmd.GetTemporaryRT(myBufferID, descriptor, FilterMode.Bilinear);
        myBuffer = new RenderTargetIdentifier(myBufferID);

        cmd.SetGlobalFloat(sizeID, size);

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

              cmd.SetGlobalTexture("_RSMDepthNormal", myBuffer);

        }

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