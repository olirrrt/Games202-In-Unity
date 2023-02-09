using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class RSMPass : ScriptableRenderPass
{
    const string ProfilerTag = "RSM Pass";

    RSMFeature.PassSettings passSettings;

    RenderTargetIdentifier colorBuffer, myBuffer;
    int myBufferID = Shader.PropertyToID("RSMDepthBuffer");
    int lightVPMatID = Shader.PropertyToID("_light_MatrixVP");
    int InvlightVPMatID = Shader.PropertyToID("_inverse_light_MatrixVP");
    int sizeID = Shader.PropertyToID("_RSMTextureSize");
    Material material;

    List<ShaderTagId> shaderTags = new() { new ShaderTagId("UniversalForward"), new ShaderTagId("SRPDefaultUnlit") };
    DrawingSettings drawingSettings;
    FilteringSettings filteringSettings = new(RenderQueueRange.opaque);

    Matrix4x4 mainLightMat;
    Transform light;

    public RSMPass(RSMFeature.PassSettings passSettings)
    {
        this.passSettings = passSettings;

        renderPassEvent = passSettings.renderPassEvent;
        light = passSettings.light;
        if (material == null) material = CoreUtils.CreateEngineMaterial("Custom/RSMHandle-DNormal");


    }


    // 初始化相机参数
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // Grab the camera target descriptor. We will use this when creating a temporary render texture.
        RenderTextureDescriptor defalut = renderingData.cameraData.cameraTargetDescriptor;

        // Grab the color buffer from the renderer camera color target.
        colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;

        // 创建 temporary rt, 名字为myBufferID，指定render target
        RenderTextureDescriptor descriptor = new() { width = 1024, height = 1024, colorFormat = RenderTextureFormat.ARGB32, msaaSamples = 1, dimension = TextureDimension.Tex2D };
        cmd.GetTemporaryRT(myBufferID, descriptor, FilterMode.Bilinear);
        myBuffer = new RenderTargetIdentifier(myBufferID);

        cmd.SetGlobalFloat(sizeID, 1024);

        var viewMat = Matrix4x4.LookAt(light.position, light.position + light.forward, light.up);// light.localToWorldMatrix;
        //ewMat = light.localToWorldMatrix;

        var s = 20;
        var ortho = Matrix4x4.Ortho(-s, s, -s, s, 0.2f, s);
        //  Debug.Log(viewMat);

        cmd.SetGlobalMatrix(lightVPMatID, ortho * viewMat);
        cmd.SetGlobalMatrix(InvlightVPMatID, Matrix4x4.Inverse(ortho * viewMat));

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
        //  cmd.ClearRenderTarget(true, true, Color.black);
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