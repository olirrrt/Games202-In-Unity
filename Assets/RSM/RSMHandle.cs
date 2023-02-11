using UnityEngine;

[ExecuteInEditMode]
public class RSMHandle : MonoBehaviour
{
    Camera virtualCam;

    readonly int lightVPMatID = Shader.PropertyToID("_light_MatrixVP");
    readonly int InvlightVPMatID = Shader.PropertyToID("_inverse_light_MatrixVP");

    void UpdateLightMatVP(Camera camera)
    {

        var matVP = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true) * camera.worldToCameraMatrix;

        Shader.SetGlobalMatrix(lightVPMatID, matVP);
        Shader.SetGlobalMatrix(InvlightVPMatID, Matrix4x4.Inverse(matVP));
    }

    void InitCamera()
    {
        if (virtualCam == null)
            virtualCam = this.GetComponent<Camera>();
        virtualCam.orthographic = true;
        virtualCam.enabled = false;
        virtualCam.orthographicSize = 2.0f;
        virtualCam.aspect = 1.0f;
        virtualCam.farClipPlane = 8;
    }

    private void Start()
    {
        InitCamera();
        UpdateLightMatVP(virtualCam);
    }

    private void Update()
    {
        UpdateLightMatVP(virtualCam);
    }
}