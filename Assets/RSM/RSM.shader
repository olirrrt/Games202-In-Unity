Shader "Custom/RSM"
{
    Properties
    { 
        //_TangentMap("TangentMap", 2D) = "white" {}
        _BaseColor("color", Color) = (0.5, 0.5, 0.5, 0)
    }


    SubShader
    {

        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
        }

        Pass
        {
             Name "RSM"
             Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN


            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

            #include "rsm.hlsl"
         
            ENDHLSL
        }
          Pass
        {
             Name "RSMFLux"
             Tags { "LightMode" = "RSMFLux" }

            HLSLPROGRAM

            #pragma vertex RSMVert
            #pragma fragment fluxFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

            #include "rsmPrePass.hlsl"
         
         
            ENDHLSL
        }
    }
}