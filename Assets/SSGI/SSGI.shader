Shader "Custom/SSGI"
{
    Properties
    { 
       _MainTex ("Texture", 2D) = "white"
    }


    SubShader
    {

        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
             Name "SSGI"
             Tags { "LightMode" = "SRPDefaultUnlit" }

            HLSLPROGRAM

            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT 

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

            #include "SSGI.hlsl"
         
            ENDHLSL
        }
    }
}