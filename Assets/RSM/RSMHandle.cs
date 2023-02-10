using UnityEngine;

[ExecuteInEditMode]
public class RSMHandle : MonoBehaviour
{
    Camera virtualCam;
    // public Light mainLight;
    int lightVPMatID = Shader.PropertyToID("_light_MatrixVP");
    int InvlightVPMatID = Shader.PropertyToID("_inverse_light_MatrixVP");

    void UpdateLightMatVP(Camera camera)
    {
        // ？设置为true会原点上下颠倒，d3d原点在左上, 否则会近远平面颠倒
        var matVP = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true) * camera.worldToCameraMatrix;
        // matVP.SetRow(1, -1 * matVP.GetRow(1));

        Shader.SetGlobalMatrix(lightVPMatID, matVP);
        Shader.SetGlobalMatrix(InvlightVPMatID, Matrix4x4.Inverse(matVP));
        Debug.Log(matVP);
        Debug.Log(GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false));
    }

    void InitCamera()
    {
        if (virtualCam == null)
            virtualCam = this.GetComponent<Camera>();
        virtualCam.orthographic = true;
        // virtualCam.enabled = true;
        virtualCam.orthographicSize = 3.0f;
        virtualCam.aspect = 1.0f;
        virtualCam.farClipPlane = 500;
        UpdateLightMatVP(virtualCam);
    }

    private void Start()
    {
        InitCamera();
    }

    private void Update()
    {
        InitCamera();
    }
}