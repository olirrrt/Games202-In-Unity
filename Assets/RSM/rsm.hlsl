#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#define NUM_SAMPLES 20
#define NUM_RINGS 10

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
    OUT.normalWS = normalWS;
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
 
float rand_2to1(float2 uv)
{
  // 0 - 1
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, float2(a, b)), sn = (dt % PI);
    return frac(sin(sn) * c);
}
float2 poissonDisk[NUM_SAMPLES];
float _sampleRadius; // rmax
void poissonDiskSamples(const in float2 randomSeed)
{

    float ANGLE_STEP = TWO_PI * float(NUM_RINGS) / float(NUM_SAMPLES);
    float INV_NUM_SAMPLES = 1.0 / float(NUM_SAMPLES);

    float angle = rand_2to1(randomSeed) * TWO_PI;
    float radius = INV_NUM_SAMPLES;
    float radiusStep = radius;

    for (int i = 0; i < NUM_SAMPLES; i++)
    {
        poissonDisk[i] = float2(cos(angle), sin(angle)) * pow(radius, 0.75);
        radius += radiusStep;
        angle += ANGLE_STEP;
    }
}

half4 rsm2(float3 p_pos, float3 p_normal)
{
    float step = 1.0 / _RSMTextureSize;
    float4 shadowCoord = mul(_light_MatrixVP, p_pos);
    shadowCoord.xyz /= shadowCoord.w;
    shadowCoord.xy = shadowCoord.xy * 0.5 + float2(0.5, 0.5);
    float2 uv;
    half4 col = half4(0, 0, 0, 0);
    // 采样距uv平方衰减
    // x1,x2是均匀分布的随机变量，有(u + r * x1 * sin(2pi * x2), v + r * x1 * cos(2pi * x2))
    // ?距离近，采样密度高，乘x1^2平衡权重
    for (int i = 0; i < NUM_SAMPLES; i++)
    {
        uv = shadowCoord.xy + poissonDisk[i] * step * _sampleRadius;
        
    }
   
    return col;
}

half4 rsm(float3 p_pos, float3 p_normal)
{


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

    half4 col = half4(0, 0, 0, 1);
    col.rgb = light.color * _BaseColor * max(0, dot(IN.normalWS, light.direction)) * light.shadowAttenuation;
    //return rsm(IN.positionWS, IN.normalWS);
    return col + rsm(IN.positionWS, IN.normalWS);
 
}
