#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#include "../CommonLib/random.hlsl"

#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

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
float _Thickness;

/*
返回一个局部坐标系的位置
参数 pdf 是采样的概率，参数 s 是随机数状态
*/
float3 SampleHemisphereUniform(inout float s, out float pdf)
{
    float2 uv = hash12(s);
    float z = uv.x;
    float phi = uv.y * TWO_PI;
    float sinTheta = sqrt(1.0 - z * z);
    float3 dir = float3(sinTheta * cos(phi), sinTheta * sin(phi), z);
    pdf = INV_TWO_PI;
    return dir;
}

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
        bool intersect = posCS.w - depth > 0 && posCS.w - depth < _Thickness;
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
    return flag ? half4(0, 1, 0, 0) : half4(1, 0, 0, 0);
}
// diffuse 半球表面随机生成采样点，取平均
half4 GetGIColor(float2 uv)
{
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}

void RayMarchScreenSpace(float2 startPos, float2 endPos, float startZ, float endZ, inout float2 hitPos)
{
    half4 col = half4(0, 0, 0, 0);
    
    float2 delta = endPos - startPos;
    bool permute = false;
    if (abs(delta.x) < abs(delta.y))
    {
        permute = true;
        delta = delta.yx;
    }
    
    float stepDir = sign(delta.x), invdx = stepDir / delta.x; // sign取符号, -1 、1 or 0 
    float2 stepXY = float2(stepDir, delta.y * invdx); // (1, slope)
    if (permute)
    {
        stepXY.yx = stepXY;
    }
    stepXY *= _MainTex_TexelSize.xy;
       
    float stepZ = (endZ - startZ) * (invdx) * max(_MainTex_TexelSize.x, _MainTex_TexelSize.y);
  
    float2 posXY = startPos, posZ = (startZ);
    int i = 1;
    for (; i <= _RayMarch_Sample_Num; i++)
    {
        posXY += stepXY;
        posZ += stepZ;
        
        float curLinearDepth = 1 / posZ.y;
        
        if (curLinearDepth > _ProjectionParams.z / 50)// far plane
            break;
            // return half4(1, 0, 0, 0);
   
        float2 uv = posXY;
        
        // 裁剪
        if (uv.x < 0 || uv.y < 0 || uv.x > 1 || uv.y > 1)
            break;
           // return half4(0, 1, 0, 0);
        
        float depth = SAMPLE_TEXTURE2D_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0).r;
        
        depth = LinearEyeDepth(depth, _ZBufferParams);

        bool intersect = curLinearDepth - depth > 0 && curLinearDepth - depth < _Thickness;

        if (intersect)
        {
            hitPos = uv;
            //return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0);
        }
    }

   // return col;
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


    float3 posWS = ComputeWorldSpacePosition(uv, depth, _my_matrixInvVP);
    float3 posVS = mul(_my_matrixV, float4(posWS, 1)); // 右手系 
    float4 posCS = mul(_my_matrixP, float4(posVS, 1)); // 左手系 

    posNDC = Clip2NDC(posCS);
    
    float3 V = normalize(_WorldSpaceCameraPos - posWS);
    float3 R = normalize(reflect(-V, normalWS));
    float3 endPosWS = posWS + _Max_Ray_March_Length * R;
    float4 endPosCS = mul(_my_matrixVP, float4(endPosWS, 1));
    
    float3 endPosNDC = Clip2NDC(endPosCS);
    
    float2 hitPos = float2(-1, -1);
    RayMarchScreenSpace(posNDC.xy, endPosNDC.xy, 1.0 / posCS.w, 1.0 / endPosCS.w, hitPos);
    if (hitPos.x > -1)
        col = GetGIColor(hitPos);
    
    return col;
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
    //return SSR(input.uv);
 
    return SSRScreenSpace(input.uv);
}
