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
 
    float2 uv : TEXCOORD1;
 
};

 

Varyings vert(Attributes IN)
{
    Varyings OUT;
    float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
    
    float4 positionCS = mul(UNITY_MATRIX_VP, float4(positionWS, 1));
  
    
    OUT.positionHCS = positionCS;

 
    OUT.normalWS = normalWS;
    OUT.uv = IN.texcoord;
    return OUT;
}



half4 frag(Varyings IN) : SV_Target
{
    IN.normalWS = normalize(IN.normalWS);
    float3 normalVS = normalize(mul(UNITY_MATRIX_V, float4(IN.normalWS, 1)).xyz);
    //normalVS.z *= -1;
  //  normalVS = normalVS * 0.5 + 0.5;
    

    return half4(normalVS, 1);
}

