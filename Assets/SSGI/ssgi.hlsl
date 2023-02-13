#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


struct Attributes
{
    float4 positionOS : POSITION;
    half3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
};

struct Varyings
{
    float4 positionHCS : SV_POSITION;
    half3 normalWS : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 tangentWS : TEXCOORD2;
    float2 uv : TEXCOORD3;
};

Varyings vert(Attributes input)
{
    Varyings output;
    output.positionHCS = TransformObjectToHClip(input.positionOS);
    output.uv = input.uv;
    return output;
}
// albedo   albedo  albedo  materialFlags   (sRGB rendertarget)
TEXTURE2D(_GBuffer0);
SAMPLER(sampler_GBuffer0);

TEXTURE2D(_GBuffer1);
SAMPLER(sampler_GBuffer1);

// encoded-normal  encoded-normal  encoded-normal  smoothness
TEXTURE2D(_GBuffer2);
SAMPLER(sampler_GBuffer2);

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

int _RayMarch_Sample_Num;
int _Sample_Num;
float _Step;
float4x4 _my_matrixVP;

half4 RayMarch(float3 ro, float3 rd)
{
    half4 res = half4(0, 0, 0, 0);
    float3 pos;
    for (int i = 0; i < _RayMarch_Sample_Num; i++)
    {
        pos = ro + i * _Step;
        float3 ndc = ComputeNormalizedDeviceCoordinatesWithZ(pos, _my_matrixVP);
        float2 uv = ndc.xy;
        float depth = SAMPLE_TEXTURE2D_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0).r;
        
#if UNITY_REVERSED_Z
        bool intersect = depth < ndc.z;
#else
        depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
        bool intersect = depth > ndc.z;
#endif
        if (intersect)
        {
           // return half4(1, 0, 0, 1);
            half4 col = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0);
            return col;
        }
    }
    return res;
}

half4 SSR(float2 uv)
{
    half4 col = half4(0, 0, 0, 1);
    
    float3 N = normalize(UnpackNormal(SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv).rgb));
    float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
    
#if UNITY_REVERSED_Z
    if (depth < 1e-6)
        return col;
#else
    if (depth > 0.99)
        return col;
    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
#endif
      
    float3 pos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
     
    float3 V = normalize(_WorldSpaceCameraPos - pos);
    float3 R = reflect(-V, N);
    
    return RayMarch(pos, R);
}

half4 frag(Varyings input) : SV_Target
{
    return SSR(input.uv);
    half4 col = half4(0, 0, 0, 1);
    return col;
}
