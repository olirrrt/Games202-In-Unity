#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

// https://www.shadertoy.com/view/4djSRW
float rand11(float x)
{
    return frac(sin(x) * 100000.0);
}

float rand21(float2 xy)
{
    return frac(sin(dot(xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float hash21(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float hash11(float p)
{
     
    p = frac(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float2 hash22(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);

}

float3 hash33(float3 p)
{
    p = float3(dot(p, float3(127.1, 311.7, 74.7)),
			  dot(p, float3(269.5, 183.3, 246.1)),
			  dot(p, float3(113.5, 271.9, 124.6)));

    return frac(sin(p) * 43758.5453123);
}

float3 hash13(float p)
{
    float3 p3 = frac(float3(p, p, p) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xxy + p3.yzz) * p3.zyx);
}
 

float2 hash12(float p)
{
    float3 p3 = frac(float3(p, p, p) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}


 

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
