// The structure definition defines which variables it contains.
// This example uses the Attributes structure as an input structure in
// the vertex shader.
struct Attributes
{
    // The positionOS variable contains the vertex positions in object
    // space.
    float4 positionOS : POSITION;
    half3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
};

struct Varyings
{
    // The positions in this struct must have the SV_POSITION semantic.
    float4 positionHCS : SV_POSITION;
    half3 normalWS : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 tangentWS : TEXCOORD2;
};

// The vertex shader definition with properties defined in the Varyings
// structure. The type of the vert function must match the type (struct)
// that it returns.
Varyings vert(Attributes IN)
{
    // Declaring the output object (OUT) with the Varyings struct.
    Varyings OUT;
    // The TransformObjectToHClip function transforms vertex positions
    // from object space to homogenous space
    OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
    OUT.positionWS = vertexInput.positionWS;

    VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
    OUT.tangentWS = normalInput.tangentWS;

    return OUT;
}
half4 T;
half rsm(float3 positionWS, float3 normalWS)
{
    // 划掉：半球表面均匀生成采样点，从切线空间转换到世界空间
    // 遍历shadow map，每个纹素视作一个点q，从深度值还原q的世界坐标
    // 根据p、q法线、位置、flux，计算贡献
}

// The fragment shader definition.
half4 frag(Varyings IN) : SV_Target
{
    // Defining the color variable and returning it.
    half4 customColor;
    customColor = half4(0.5, 0.5, 0.5, 1);

    return customColor;
}