Shader "Custom/RSMHandle-Flux"
{
    Properties
    { 
        //_TangentMap("TangentMap", 2D) = "white" {}
        //T("tangent", Color) = (0.5, 0.5, 0.5, 0)
    }


    SubShader
    {

        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }


        Pass
        {
            Name "flux"
            Tags{"LightMode"="SRPDefaultUnlit"}
                // The HLSL code block. Unity SRP uses the HLSL language.
                HLSLPROGRAM
                // This line defines the name of the vertex shader. 
                #pragma vertex vert
                // This line defines the name of the fragment shader. 
                #pragma fragment fluxFrag

                // The Core.hlsl file contains definitions of frequently used HLSL
                // macros and functions, and also contains #include references to other
                // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

                #include "rsmHandle.hlsl"
         
                ENDHLSL
        }
    }
}