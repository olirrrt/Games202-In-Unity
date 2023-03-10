Shader "Custom/Hiz"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
    
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS);
                output.uv = input.uv;
                return output;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            half4 frag (Varyings input) : SV_Target
            {
                // 生成hi-z buffer，取周围4个点中距离最小的点
                float2 offsets[4] = { float2(1, 1), float2(0, 1), float2(1, 0), float2(0, 0) };
                float minDepth = 0;
                for(int i = 0;i < 4; i++){
                    float depth =  tex2D(_MainTex, input.uv + offsets[i] * _MainTex_TexelSize.xy);
                    #if UNITY_REVERSED_Z
                        minDepth = max(minDepth, depth);
                    #else
                        minDepth = min(minDepth, depth);
                    #endif
                }              
                return half4(minDepth, 0, 0, 0);
            }
            ENDHLSL
        }
    }
}
