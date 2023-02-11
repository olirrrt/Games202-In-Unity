Shader "Custom/RSMPrePass"
{

    SubShader
    {

        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
          

        Pass
        {
            Name "depth normal"

            Tags{"LightMode" = "UniversalForward"}

                HLSLPROGRAM
                #pragma vertex RSMVert
                #pragma fragment frag

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

                #include "rsmPrePass.hlsl"
         
                ENDHLSL
        }

    }
}