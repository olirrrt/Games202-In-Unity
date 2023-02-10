#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
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

Varyings vert(Attributes IN)
{
    Varyings OUT;

    OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
    OUT.positionWS = vertexInput.positionWS;

    VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
    OUT.tangentWS = normalInput.tangentWS;
    OUT.uv = IN.texcoord;
    return OUT;
}

float _RSMTextureSize;
TEXTURE2D(_RSMDepthNormal);
SAMPLER(sampler_RSMDepthNormal);
 
TEXTURE2D(_RSMFlux);
SAMPLER(sampler_RSMFlux);

float4x4 _light_MatrixVP;
float4x4 _inverse_light_MatrixVP;

float Rand1(inout float p)
{
    p = frac(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float2 Rand2(inout float p)
{
    return float2(Rand1(p), Rand1(p));
}

// TransformWorldToShadowCoord(vertexInput.positionWS);
half4 rsm(float3 p_pos, float3 p_normal)
{
    float4 shadowCoord = mul(_light_MatrixVP, p_pos);
    shadowCoord.xyz /= shadowCoord.w;
    shadowCoord.xy *= 0.5;
    shadowCoord.xy += 0.5;
    // 遍历shadow map，每个纹素视作一个点q，从深度值还原q的世界坐标
    // 根据p、q法线、位置、flux，计算贡献
    // q点flux * dot(n_p, q-p) * dot(n_q, q-p) / dis(p,q)^2
    float step = 1.0 / _RSMTextureSize;
    half4 col = half4(0, 0, 0, 0);
    int num = 0;
    for (float x = 0; x < 1; x += step)
    {
        for (float y = 0; y < 1; y += step)
        {
            float2 uv = float2(x, y);
            float4 q_dnormal = SAMPLE_TEXTURE2D(_RSMDepthNormal, sampler_RSMDepthNormal, uv);
            if (q_dnormal.a < 1e-6)
                continue;
            
            float3 q_normal = q_dnormal.rgba;
            q_normal = normalize(q_normal * 2 - float3(1, 1, 1));
            float3 q_pos = ComputeWorldSpacePosition(uv, q_dnormal.a, _inverse_light_MatrixVP);
            float4 q_flux = SAMPLE_TEXTURE2D(_RSMFlux, sampler_RSMFlux, uv);
            
            col += q_flux * max(0, dot(p_normal, normalize(q_pos - p_pos))) * max(0, dot(q_normal, normalize(p_pos - q_pos))) / pow(distance(p_pos, q_pos), 2);
          //  col += q_flux;
            num++;
        }
    }
    return col / num;
}



half4 frag(Varyings IN) : SV_Target
{
    float d = IN.positionHCS.z / IN.positionHCS.w;
   // 
    float4 shadowCoord = mul(_light_MatrixVP, float4(IN.positionWS, 1));
    shadowCoord.xyz /= shadowCoord.w;
    shadowCoord.xy *= 0.5;
    shadowCoord.xy += 0.5;
    d = shadowCoord.z;
    return shadowCoord;
    return half4(d, d, d, 1);
    return rsm(IN.positionWS, IN.normalWS);
    // Defining the color variable and returning it.
   /* half4 customColor = 0;
    half2 uv = IN.positionHCS / _ScaledScreenParams.xy;
    
   
    uv = shadowCoord.xy;
    customColor = SAMPLE_TEXTURE2D(_RSMFlux, sampler_RSMFlux, uv);
    customColor = SAMPLE_TEXTURE2D(_RSMDepthNormal, sampler_RSMDepthNormal, uv);*/
  //  return customColor; 

}