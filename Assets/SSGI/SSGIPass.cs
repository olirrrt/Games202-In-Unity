using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class SSGIPass : ScriptableRenderPass
{
    const string ProfilerTag = "SSGI Pass";

    RenderTargetIdentifier colorBuffer, myBuffer;
    readonly int myBufferID = Shader.PropertyToID("RSMDepthBuffer");
    readonly int rayMarchSampleNumID = Shader.PropertyToID("_RayMarch_Sample_Num");
    readonly int sampleNumID = Shader.PropertyToID("_Sample_Num");
    readonly int rayMarchStepID = Shader.PropertyToID("_Step");
    readonly int matrixVPID = Shader.PropertyToID("_my_matrixVP");
    readonly int matrixInvVPID = Shader.PropertyToID("_my_matrixInvVP");
    readonly int matrixVID = Shader.PropertyToID("_my_matrixV");
    readonly int matrixPID = Shader.PropertyToID("_my_matrixP");
    readonly int matrixInvVID = Shader.PropertyToID("_my_matrixInvP");
    readonly int maxMarchLenID = Shader.PropertyToID("_Max_Ray_March_Length");

    SSGIFeature.PassSettings passSettings;

    Material material;
    Material blendMaterial;
    List<ShaderTagId> shaderTags = new() { new ShaderTagId("UniversalForward") };
    DrawingSettings drawingSettings;
    FilteringSettings filteringSettings = new(RenderQueueRange.opaque);


    public SSGIPass(SSGIFeature.PassSettings passSettings)
    {
        this.passSettings = passSettings;
        renderPassEvent = passSettings.renderPassEvent;
        if (material == null) material = CoreUtils.CreateEngineMaterial("Custom/SSGI");
        if (blendMaterial == null) blendMaterial = CoreUtils.CreateEngineMaterial("Custom/Tool/AlphaBlend");


    }


    // 初始化相机参数
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTextureDescriptor defalut = renderingData.cameraData.cameraTargetDescriptor;
        colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;

        // 创建 temporary rt, 名字为myBufferID，指定render target
        var descriptor = new RenderTextureDescriptor(defalut.width, defalut.height, RenderTextureFormat.ARGB32, 32, 1);

        cmd.GetTemporaryRT(myBufferID, descriptor, FilterMode.Bilinear);
        myBuffer = new RenderTargetIdentifier(myBufferID);

        var matVP = GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, true) * Camera.main.worldToCameraMatrix;
        material.SetMatrix(matrixVPID, matVP); //?设置自定义矩阵，unity_i_vp也自动更新了
        material.SetMatrix(matrixInvVPID, Matrix4x4.Inverse(matVP)); //?设置自定义矩阵，unity_i_vp也自动更新了
        material.SetMatrix(matrixVID, Camera.main.worldToCameraMatrix);
        material.SetMatrix(matrixInvVID, Matrix4x4.Inverse(GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, true)));
        material.SetMatrix(matrixPID, GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, true));

        material.SetInt(rayMarchSampleNumID, passSettings.RayMarchSampleNum);
        material.SetInt(sampleNumID, passSettings.IndirectLightSampleNum);
        material.SetFloat(rayMarchStepID, passSettings.RayMarchStep);
        //   Shader.SetGlobalMatrix("_unity_MatrixVP", matVP);

        material.SetFloat(maxMarchLenID, passSettings.maxRayMarchLength);

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

            Blit(cmd, colorBuffer, myBuffer, material, 0);
            Blit(cmd, myBuffer, colorBuffer);

            // Blit(cmd, myBuffer, colorBuffer, blendMaterial, 0);
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