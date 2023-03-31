using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FirstComShader : MonoBehaviour
{
    [SerializeField] ComputeShader cShader;
    [SerializeField] int num;
    [SerializeField] GameObject prefab;

    ComputeBuffer cbuffer;// gpu ? ram
    readonly int cbufferId = Shader.PropertyToID("Result");
    int kernelIdx;
    uint[] kernelSize;

    void Awake()
    {
        cbuffer = new(num, sizeof(float) * 3);

        kernelIdx = cShader.FindKernel("Spheres");

        kernelSize = new uint[3];// [numthreads(x, y, z)]的值
        cShader.GetKernelThreadGroupSizes(kernelIdx, out kernelSize[0], out _, out _);

        cShader.SetBuffer(kernelIdx, cbufferId, cbuffer);
        Debug.Log(kernelSize[0]);
        cShader.Dispatch(kernelIdx, (int)kernelSize[0], 1, 1);// execute
    }

    void Start()
    {

    }
    void Update()
    {
        cShader.SetFloat("Time", Time.time);
        cShader.Dispatch(kernelIdx, (int)kernelSize[0], 1, 1);
        JustVisualize();
    }
    List<Transform> tmpList;
    void JustVisualize()
    {
        Vector3[] data = new Vector3[num];
        cbuffer.GetData(data);
        if (tmpList == null)
        {
            tmpList = new();
            for (int i = 0; i < num; i++)
                tmpList.Add(Instantiate(prefab, transform).transform);
        }

        for (int i = 0; i < num; i++)
            tmpList[i].transform.localPosition = data[i];
    }

    void OnDestroy()
    {
        cbuffer.Dispose();
    }
}
