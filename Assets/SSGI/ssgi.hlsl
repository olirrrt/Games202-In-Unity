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
float4x4 _my_matrixInvVP;
float4x4 _my_matrixV;
float4x4 _my_matrixP;
float4x4 _my_matrixInvP;

float4 _MainTex_TexelSize;
float _Max_Ray_March_Length;

half4 RayMarch(float3 ro, float3 rd)
{
    half4 res = half4(0, 0, 0, 0);
    float3 pos;
    for (int i = 1; i <= _RayMarch_Sample_Num; i++)
    {
        pos = ro + i * _Step * rd;
        //float3 ndc = ComputeNormalizedDeviceCoordinatesWithZ(pos, _my_matrixVP);
        //float2 uv = ndc.xy; // [0, 1]
        float4 posCS = mul(_my_matrixVP, float4(pos, 1.0));

        float2 uv = posCS.xy / posCS.w;
        
#if UNITY_UV_STARTS_AT_TOP
        uv.y = -uv.y;
#endif
        uv = uv * 0.5 + 0.5;
        
        // 裁剪
        if (uv.x < 0 || uv.y < 0 || uv.x >= 1 || uv.y >= 1)
            return res;
        
        float depth = SAMPLE_TEXTURE2D_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0).r;
        
//#if UNITY_REVERSED_Z
        depth = LinearEyeDepth(depth, _ZBufferParams); // 线性深度，近小远大 posCS.w > depth
        bool intersect = depth - posCS.w < 1e-6;
//#else
 //       depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
//        depth = LinearEyeDepth(depth, _ZBufferParams);
//        bool intersect = depth - posCS.w > 1e-6;
//#endif
        if (intersect)
        {
            //return half4(1, 0, 0, 1);
           

            half4 col = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0);
            return col;
        }
    }
    return res;
}

half4 SSR(float2 uv)
{
    half4 col = half4(0, 0, 0, 0);
    
    float3 N = normalize(UnpackNormal(SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv).rgb));
    float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;

#if UNITY_REVERSED_Z
    if (depth < 1e-6)
        return col;
#else
    if (depth > 0.99)
        return col;
#endif
      
    float3 pos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
    float3 test = ComputeNormalizedDeviceCoordinatesWithZ(pos, _my_matrixVP);
    
    float3 V = normalize(_WorldSpaceCameraPos - pos);
    float3 R = normalize(reflect(-V, N));

    return RayMarch(pos, R);
}

half4 Debug(bool flag)
{
    return flag ? half4(1, 0, 0, 0) : half4(0, 1, 0, 0);
}

/*
xy: [0, 1]，步长记得用_MainTex_TexelSize.xy缩放!
分子num: [start, end]
分母denom: [start, end]
*/
half4 RayMarchScreenSpace(float2 startPos, float2 endPos, float2 startZ, float2 endZ)
{
    half4 col = half4(0, 0, 1, 0);
    
    float2 delta = endPos - startPos;
    bool permute = false;
    if (abs(delta.x) < abs(delta.y))
    {
        permute = true;
        delta = delta.yx;
    }
    
    float stepDir = sign(delta.x), invdx = stepDir / delta.x; // sign取符号, -1 、1 or 0 
    float2 stepXY = float2(stepDir, delta.y * invdx) * _MainTex_TexelSize.xy; // (1, slope)
    if (permute)
        stepXY.yx = stepXY;
    
    float2 stepZ = (endZ - startZ) * abs(invdx);
    
    float2 posXY = startPos, posZ = startZ;
    for (int i = 1; i <= _RayMarch_Sample_Num && (posXY.x < endPos.x || posXY.y < endPos.y); i++)
    {
        posXY += stepXY;
        posZ += stepZ;
        
        float curLinearDepth = posZ.x / posZ.y;
        return half4(curLinearDepth / 10, 0, 0, 0);
        float2 uv = posXY;
        
        // 裁剪
        if (uv.x < 0 || uv.y < 0 || uv.x > 1 || uv.y > 1)
            return half4(0, 1, 0, 0);
        
        float depth = SAMPLE_TEXTURE2D_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0).r;
#if UNITY_REVERSED_Z
        if (depth < 1e-6)
             return col;
#else
        if (depth > 0.99)
            return col;
#endif
        
        depth = LinearEyeDepth(depth, _ZBufferParams);

        bool intersect = depth < curLinearDepth; // < 1e-6;

        if (intersect)
        {
           // return half4(1, 0, 0, 0);
            return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0);
        }
    }
    
    return col;
}

float3 Clip2NDC(float4 posCS)
{
#if UNITY_UV_STARTS_AT_TOP
    posCS.y *= -1;
#endif
    
    posCS *= rcp(posCS.w);
    
    posCS.xy = posCS.xy * 0.5 + 0.5;
    
    return posCS.xyz;
}

half4 SSRScreenSpace(float2 uv)
{

    half4 col = half4(0, 0, 0, 0);
    
    float3 normalWS = normalize(UnpackNormal(SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv).rgb));
    float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;

#if UNITY_REVERSED_Z
    if (depth < 1e-6)
        return col;
#else
    if (depth > 0.99)
        return col;
    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
#endif
    
    // NDC: xy[0,1], z[0,1]
    // CS: xy[-w,w], z[0,w] 透视除法后: xy[-1,1], z[0,1]
    float3 posNDC = float4(uv + 0.5 * _MainTex_TexelSize.xy, depth, 1);

    float3 posWS = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP); // 左手系
    float3 posVS = mul(_my_matrixV, float4(posWS, 1));
    float4 posCS = mul(_my_matrixP, float4(posVS, 1));

    
    float3 normalVS = normalize(mul(_my_matrixV, float4(normalWS, 1)).xyz);
    float3 reflectVS = normalize(reflect(posVS, normalVS));
    float3 endPosVS = posVS + _Max_Ray_March_Length * reflectVS; // endPosVS.z > 0

    float4 endPosCS = mul(_my_matrixP, float4(endPosVS, 1)); // endPosCS.z > 0  .w < 0
    float3 endPosNDC = Clip2NDC(endPosCS);
    
    //endPosNDC.xy = clamp(endPosNDC.xy, float2(0, 0), float2(1, 1));
    //depth = LinearEyeDepth(depth, _ZBufferParams);
    //return half4(depth / 20, 0, 0, 0);
    //return Debug(endPosVS.z > 0);
    
    
    //  linear z / w 
    //------------------
    //      1 / w
    //float2 denom = float2(1.0 / posCS.w, 1.0 / endPosCS.w);
   // float2 num = float2(posVS.z * denom.x, endPosVS.z * denom.y);
    float2 startZ = float2(posVS.z / posCS.w, 1.0 / posCS.w);
    float2 endZ = float2(endPosVS.z / endPosCS.w, 1.0 / endPosCS.w);
    
    
    depth = LinearEyeDepth(depth, _ZBufferParams);
    float depth2 = startZ.x / startZ.y;
    return Debug(depth > depth2);

    //float3 normalWS2 = normalize(UnpackNormal(SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, endPosNDC.xy).rgb));
    //return half4(endPosNDC.xy, 0, 1);
    
    return RayMarchScreenSpace(posNDC.xy, endPosNDC.xy, startZ, endZ);
}

half4 frag(Varyings input) : SV_Target
{
    // positionCS ([-w, w], ?, ?)
    // positionHCS (width, height, ?, ?)
    // float2 uv = input.positionHCS.xy / input.positionHCS.w;
   // uv = uv * 0.5 + 0.5;
    // float2 uv = input.positionHCS.xy / _ScaledScreenParams.xy;
    // float3 normalWS = normalize(UnpackNormal(SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv).rgb));
    // return half4(normalWS, 1);
    //float z = input.positionHCS.z / input.positionHCS.w;
    //return half4(z, 0, 0, 1);
   // return SSR(input.uv);
    return SSRScreenSpace(input.uv);
}
