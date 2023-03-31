// https://www.shadertoy.com/view/4djSRW
float rand11(float x)
{
    return frac(sin(x) * 100000.0);
}

float rand21(float2 xy)
{
    return frac(sin(dot(xy, float2(12.9898, 78.233))) * 43758.5453123);
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