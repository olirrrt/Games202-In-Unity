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

half4 RayMarchScreenSpace(float3 ro, float3 rd, float3 endPos, float2 z, float2 k)
{
    half4 res = half4(0, 0, 0, 0);
    float2 delta = rd.xy - ro.xy;
    bool permute = false;
    if (abs(delta.x) < abs(delta.y))
    {
        permute = true;
        delta = delta.yx;
      //  ro.xy = ro.yx;
      //  endPos.xy = endPos.yx;
    }
    float stepDir = sign(delta.x), invdx = stepDir / delta.x;
    float stepZ = (z.y - z.x) * invdx; // max((y1 - y0), (x1 - x0))
    float stepK = (k.y - k.x) * invdx; //  
    float2 step = float2(stepDir, delta.y * invdx); // (1, slope)
    float3 pos = ro, posK = k.x, posZ = z.x;
    step *= _MainTex_TexelSize.xy;
    float3 linearStep = float3(step, (endPos.z - ro.z) * invdx);
    for (int i = 1; i <= _RayMarch_Sample_Num; i++)
    {
      //  pos += step;
        pos += linearStep;
        posK += stepK;
        posZ += stepZ;
        
        float rayLinearDepth = posZ / posK;
        float2 uv = pos.xy;
        float depth = SAMPLE_TEXTURE2D_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0).r;
                // 裁剪
        if (uv.x < 0 || uv.y < 0 || uv.x >= 1 || uv.y >= 1)
            return half4(0, 1, 0, 0);
      //  depth = LinearEyeDepth(depth, _ZBufferParams);
//#if UNITY_REVERSED_Z
         
     //   bool intersect = depth - rayLinearDepth < 1e-6;
      //  bool intersect = -depth + rayLinearDepth < 1e-6;
        bool intersect = depth - pos.z < 1e-6;
//#else
//#endif
        if (intersect)
        {
            //return half4(1, 0, 0, 0);
            return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, pos, 0);
        }
    }
    
    return res;
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
#endif
    // NDC: xy[0,1], z[0,1]
    // CS: xy[-w,w], z[0,w] 透视除法后: xy[-1,1], z[0,1]
    float3 posNDC = float4(uv + 0.5 * _MainTex_TexelSize.xy, depth, 1);

    //float4 posCS = ComputeClipSpacePosition(posNDC.xy, posNDC.z); // 返回 xy[-1,1] z[0,1]
    float3 posWS = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP); // 左手系 -posWS.z / 10 [1,0]
    float3 posVS = ComputeViewSpacePosition(posNDC.xy, posNDC.z, _my_matrixInvP); // 右手系 posVS.z / 10 [0,1]
    float4 posCS = ComputeClipSpacePosition(posVS, _my_matrixP); // -posCS.w / 10 近0远1
  //  posCS.w *= -1;
   // return half4(posCS.z / -posCS.w, 0, 0, 0);
  //  if (-posCS.w > 0)
   //     return half4(1, 0, 0, 0);
   // else
   //     return half4(0, 1, 0, 0);
   // return posCS;
    
    float3 normalVS = normalize(mul(_my_matrixV, float4(normalWS, 1)));
    float3 reflectVS = normalize(reflect(posVS, normalVS));
    float3 endPosVS = posVS + _Max_Ray_March_Length * reflectVS;
    float4 endPosCS = ComputeClipSpacePosition(endPosVS, _my_matrixP);
   // endPosCS.w *= -1;
    
    float3 endPosNDC = ComputeNormalizedDeviceCoordinatesWithZ(reflectVS, _my_matrixP);
    float3 reflectNDC = normalize(endPosNDC - posNDC);
    
    // non-homogeneous view/w
    float2 k = float2(1.0 / posCS.w, 1.0 / endPosCS.w);
    float2 z = float2(posVS.z * k.x, endPosVS.z * k.y);
    
    return RayMarchScreenSpace(posNDC, reflectNDC, endPosNDC, z, k);
}

half4 frag(Varyings input) : SV_Target
{
   // return SSR(input.uv);
    return SSRScreenSpace(input.uv);
}
