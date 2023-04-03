using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


public class RTFeature : MonoBehaviour
{
    public ComputeShader cShader;
    public Cubemap skybox;
    public Texture2D skybox2;
    RenderTexture rt;

    Camera rtCam;
    int kernelIdx;
    uint kernelSizeX, kernelSizeY;
    readonly int cbufferId = Shader.PropertyToID("Result");
    readonly int skyboxId = Shader.PropertyToID("_Skybox");
    readonly int invProjId = Shader.PropertyToID("_InvProj");
    readonly int worldToCamId = Shader.PropertyToID("_WorldToCam");
    readonly int camToWorldId = Shader.PropertyToID("_CamToWorld");
    void OnEnable()
    {
        RenderPipelineManager.endContextRendering += OnEndCtxRendering;
    }

    void OnDisable()
    {
        RenderPipelineManager.endContextRendering -= OnEndCtxRendering;
    }

    void Awake()
    {
        // if (rt == null)
        //{
        rt = new RenderTexture(Screen.width, Screen.height, 24);
        rt.enableRandomWrite = true;
        rt.Create();
        // }
        rtCam = gameObject.GetComponent<Camera>();


        kernelIdx = cShader.FindKernel("CSMain");
        // 初始化 & 传参
        cShader.GetKernelThreadGroupSizes(kernelIdx, out kernelSizeX, out kernelSizeY, out _);

        cShader.SetTexture(kernelIdx, cbufferId, rt);
        cShader.SetTexture(kernelIdx, skyboxId, skybox);
        cShader.SetTexture(kernelIdx, "_Skybox2", skybox2);
        cShader.SetMatrix(camToWorldId, rtCam.cameraToWorldMatrix);
        cShader.SetMatrix(worldToCamId, rtCam.worldToCameraMatrix);

        cShader.SetFloat("_FOV", rtCam.fieldOfView);
        cShader.SetMatrix(invProjId, Matrix4x4.Inverse(GL.GetGPUProjectionMatrix(rtCam.projectionMatrix, true)));
        // work group size [8,8,1]
        // the total amount of compute shader invocations = group count * group size
        //cShader.Dispatch(kernelIdx, Screen.width / (int)kernelSizeX, Screen.height / (int)kernelSizeY, 1);
        // 执行
        // ? 监听屏幕、相机变化事件
        cShader.Dispatch(kernelIdx, Mathf.CeilToInt(Screen.width / (float)kernelSizeX), Mathf.CeilToInt(Screen.height / (float)kernelSizeY), 1);


    }

    private void FixedUpdate()
    {
        // rtCam.transform.y
    }
    void Start()
    {

    }

    void OnEndCtxRendering(ScriptableRenderContext context, List<Camera> cameras)
    {
        //Debug.Log("OnEndCtxRendering");
        Graphics.Blit(rt, cameras[0].targetTexture);
    }


}