#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


struct Attributes
{
    float4 positionOS : POSITION;
    half3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
};

struct Varyings
{
    float4 positionHCS : SV_POSITION;
    half3 normalWS : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 tangentWS : TEXCOORD2;
    float2 uv : TEXCOORD3;
    float depth : TEXCOORD4;
};

float4x4 _light_MatrixVP;

Varyings RSMVert(Attributes IN)
{
    Varyings OUT;
    float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
    
    float4 positionCS = mul(_light_MatrixVP, float4(positionWS, 1));
   
    OUT.depth =mul(UNITY_MATRIX_P, float4(positionWS, 1)).x;
    OUT.depth =mul(UNITY_MATRIX_V, float4(positionWS, 1)).x + _ProjectionParams.x;

 
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
    
    OUT.positionHCS = positionCS;

    OUT.positionWS = positionWS;

    OUT.normalWS = normalWS;
    OUT.uv = IN.texcoord;
    return OUT;
}



half4 frag(Varyings IN) : SV_Target
{
    IN.normalWS = normalize(IN.normalWS);
    half3 nor = IN.normalWS * 0.5 + 0.5;
 
    half depth = IN.positionHCS.z / IN.positionHCS.w;

    return half4(nor.x, nor.y, nor.z, depth);
}

half4 _BaseColor;
 half4 fluxFrag(Varyings IN) : SV_Target
{
 //return half4(1,0,0,1);
   return _MainLightColor * _BaseColor;
 
}