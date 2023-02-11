#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

     float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);

   // VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
   OUT.positionWS = positionWS;

   // VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
   // OUT.tangentWS = normalInput.tangentWS;
    OUT.normalWS =  normalWS;
    OUT.uv = IN.texcoord;
    return OUT;
}
float4 _BaseColor;
float _RSMTextureSize;
TEXTURE2D(_RSMDepthNormal);
SAMPLER(sampler_RSMDepthNormal);

TEXTURE2D(_RSMFlux);
SAMPLER(sampler_RSMFlux);

float4x4 _light_MatrixVP;
float4x4 _inverse_light_MatrixVP;

int test;

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
    int num = 1e-6;
    for (float x = 0; x < 1; x += step)
    {
        for (float y = 0; y < 1; y += step)
        {
            float2 uv = float2(x, y);
            float4 dNormal = SAMPLE_TEXTURE2D(_RSMDepthNormal, sampler_RSMDepthNormal, uv);
            float depth = dNormal.a;
            float3 q_normal = normalize(dNormal.rgb * 2 - float3(1, 1, 1));

#if UNITY_REVERSED_Z
            if (depth < 1e-6)
                continue;
#else
            if (depth > 0.99)
                continue;
            depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
#endif
      
            float3 q_pos = ComputeWorldSpacePosition(uv, depth, _inverse_light_MatrixVP);
            float4 q_flux = SAMPLE_TEXTURE2D(_RSMFlux, sampler_RSMFlux, uv);

            col += q_flux * max(0, dot(p_normal, normalize(q_pos - p_pos))) * max(0, dot(q_normal, normalize(p_pos - q_pos))) / pow(distance(p_pos, q_pos), 2);

            num++;
        }
    }
    return col / num;
}
//TEXTURE2D(_MainLightShadowmapTexture);
//SAMPLER2D(sampler_MainLightShadowmapTexture)

half4 frag(Varyings IN) : SV_Target
{
    IN.normalWS = normalize(IN.normalWS);
    Light light = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));

    half4 col = half4(0,0,0,1);
    col.rgb = light.color * _BaseColor * max(0, dot(IN.normalWS, light.direction)) * light.shadowAttenuation;
     return  rsm(IN.positionWS, IN.normalWS);
    return col + rsm(IN.positionWS, IN.normalWS);
 
}
