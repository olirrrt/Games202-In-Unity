#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float3 _LightDirection;
float4x4 _MainLightMat;
float4x4 _ProjMat;

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
};

float4x4 _light_MatrixVP;
//float4 _BaseColor
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

Varyings vert(Attributes IN)
{
    Varyings OUT;
    float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
    
    float3 lightDirectionWS = _LightDirection;

   // float4 positionCS = mul(_MainLightWorldToShadow[0], float4(positionWS, 1));
   // light_MatrixVP = unity_MatrixVP;
    _light_MatrixVP[1] *= float4(-1, -1, -1, -1);
    float4 positionCS = mul(_light_MatrixVP, float4(positionWS, 1));

#if UNITY_REVERSED_Z
    _light_MatrixVP[2] *= float4(-1,-1,-1,-1);
#endif

/* 
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
*/
   // OUT.positionHCS = TransformWorldToShadowCoord(positionWS);//positionCS; 
    OUT.positionHCS = positionCS;

    OUT.positionWS = positionWS;

   // VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
   // OUT.tangentWS = normalInput.tangentWS;
    OUT.normalWS = normalWS;
    OUT.uv = IN.texcoord;
    return OUT;
}



half4 frag(Varyings IN) : SV_Target
{
    IN.normalWS = normalize(IN.normalWS);
    half3 nor = IN.normalWS * 0.5 + 0.5;
    half3 pos = IN.positionWS * 0.5 + 0.5;
    half depth = IN.positionHCS.z;
    half4 customColor; // = half4(1, 0.5, 0.5, 1);
    customColor = half4(nor.x, nor.y, nor.z, depth);
    //customColor = half4(pos.x, pos.y, pos.z, 1);
//customColor = half4(depth, depth, depth, 1);
    return customColor;
}

half4 fluxFrag(Varyings IN) : SV_Target
{
    half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv); // _BaseColor
    half4 flux = _MainLightColor * half4(1, 0, 0, 1);
    half4 customColor;
    customColor = half4(flux);

    return customColor;
}

half4 posFrag(Varyings IN) : SV_Target
{
    half3 pos = IN.positionWS * 0.5 + 0.5;

    return half4(pos, 1);
}