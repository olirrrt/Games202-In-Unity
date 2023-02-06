Shader "Unlit/simple anisotropic"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    { 
        _TangentMap("TangentMap", 2D) = "white" {}
        //T("tangent", Color) = (0.5, 0.5, 0.5, 0)
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader. 
            #pragma vertex vert
            // This line defines the name of the fragment shader. 
            #pragma fragment frag

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;  
                half3 normalOS        : NORMAL;
                float4 tangentOS    : TANGENT;
                
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                half3 normalWS   : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
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
                OUT.positionWS =  vertexInput.positionWS;

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.tangentWS = normalInput.tangentWS;

                return OUT;
            }
            half4 T;
            half simpleAnisoTropic(float3 L, float3 V, float3 T){
                float LdotN = sqrt(1 - dot(L, T) * dot(L, T));
                float VdotR = LdotN * sqrt(1 - dot(V, T) * dot(V, T)) - dot(V, T) * dot(L, T);
                VdotR = max(0, pow(VdotR, 3));
                //float ks = 
                return VdotR ;//+ LdotN;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                // Defining the color variable and returning it.
                half4 customColor;
                customColor = half4(0.5, 0.5, 0.5, 1);
                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                Light light = GetMainLight();
                //light.shadowAttenuation = 
                half3 col = customColor.rgb  * simpleAnisoTropic(light.direction , viewDirWS, IN.tangentWS.xyz);
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}