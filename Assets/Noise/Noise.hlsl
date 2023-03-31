float hash11(float p)
{
     
    p = frac(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}


float rand(float2 xy)
{
    return frac(sin(dot(xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float3 hash(float3 p)
{
    p = float3(dot(p, float3(127.1, 311.7, 74.7)),
			  dot(p, float3(269.5, 183.3, 246.1)),
			  dot(p, float3(113.5, 271.9, 124.6)));

    return frac(sin(p) * 43758.5453123);
}

float2 hash22(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);

}


float ring(float2 uv, float2 center = 0.5)
{
    half r = length(uv - center);
    float s1 = smoothstep(0.2, 0.25, r);
    float s2 = smoothstep(0.25, 0.3, r);
    return s1 - s2;
}

float ring(float r)
{
    return smoothstep(-0.6, -0.5, r) * smoothstep(0, -0.3, r);
    
    float s1 = smoothstep(0.2, 0.25, r);
    float s2 = smoothstep(0.25, 0.3, r);
    return s1 - s2;
    
}

float voronoiNoise(float2 uv, float tile)
{
    uv *= tile;
    float2 baseCell = floor(uv);

    float minDistToCell = 10;
    [unroll]
    for (int i = -1; i <= 1; i++)
    {
        [unroll]
        for (int j = -1; j <= 1; j++)
        {
            float2 cell = baseCell + float2(i, j); // 相邻格子及其内圆心
            float2 cellCenter = cell + hash22(cell);
 
            float distToCell = length(cellCenter - uv); // 点到周围圆心的最短距离
            if (distToCell < minDistToCell)
            {
                minDistToCell = distToCell;
            }
        }
    }
    return minDistToCell;
}

void simpleRandom_float(float2 uv, float tile, float radius, float time, out float4 col)
{
    col = float4(0, 0, 0, 1);

    uv *= tile;
    
    float2 baseCell = floor(uv); // cell index 

    
    for (int i = -radius; i <= radius; i++)
    {
        for (int j = -radius; j <= radius; j++)
        {
            float2 cell = baseCell + float2(i, j);
            float2 cellCenter = cell + hash22(cell);
              
            float t = frac((time) * 0.1); // 时间随机偏移量
            float2 dir = cellCenter - uv;
            float distToCell = length(dir);
                     
           // t = 1;
            float cicle = distToCell - (radius + 1) * t; // 当前点到周围格子圆心的距离，在最大半径的范围内
            
            float deltaH = 1e-3; // 有限差分从高度图（灰度）计算法线
            float c = cicle - deltaH;
            float c1 = cicle + deltaH;
            float w = 33;
            float r = sin(w * c) * ring(c); // sinwx, 频率决定圈数
            float r1 = sin(w * c1) * ring(c1);
            //cicle ;
           // col.rgb += normalize(float3(dir.x, 1, dir.y)) * (r1 - r);
            col.rg += 0.5 * normalize(dir) * (r1 - r) / (2 * deltaH * (1 - t) * (1 - t)); // 随时间衰减


        }
    }
    col.rg /= (2 * radius + 1) * (2 * radius + 1);
    //col = float4(ripple(frac(uv)), 0, 1);
   // col = float4(test.xy, 0, 1);
   // col = float4(col.xy / tile, 0, 1);
}