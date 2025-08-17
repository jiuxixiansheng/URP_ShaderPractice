Shader "sza/default"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_Specular ("Specular Color", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
		[Toggle(_AdditionalLights)] _AddLights ("AddLights", Float) = 1
		//���Դ���㿪��
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline" = "UniversalPipeline"}

		pass
		{
			Tags{"LightMode"="UniversalForward"}
			HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			//URP���ñ���
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			//������Ⱦ��������

			#pragma shader_feature _AdditionalLights
			//���Դ����Ŀ��ر���	
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma shader_feature _ADD_LIGHTS
            //������Ӱ�ı���ؼ���
			
			#pragma vertex vert
			#pragma fragment frag

			CBUFFER_START(UnityPerMaterial)
			float4 _Color;
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float4 _Specular;
			float _Gloss;
			CBUFFER_END
			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_BumpMap);
			SAMPLER(sampler_BumpMap);
		
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			}; 
		
			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float4 TtoW0 : TEXCOORD1;  
                float4 TtoW1 : TEXCOORD2;  
                float4 TtoW2 : TEXCOORD3; 
			};
			
			v2f vert(a2v v) {
			 	v2f o;
			 	o.pos = TransformObjectToHClip(v.vertex);
			 
			 	o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
			 	o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				
				float3 worldPos = TransformObjectToWorld(v.vertex.xyz); 
                float3 worldNormal = TransformObjectToWorldNormal(v.normal); 
                float3 worldTangent = TransformObjectToWorldDir(v.tangent.xyz);  
                float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
                
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
			 	
			 	return o;
			}
			
			float4 frag(v2f i) : SV_Target {
				Light mainLight = GetMainLight();
				//��ȡ��Դ��Ϣ�ĺ���
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				float4 shadowCoord = TransformWorldToShadowCoord(worldPos);
				float3 LightColor = GetMainLight(shadowCoord).color;
				float3 lightDir = normalize(TransformObjectToWorldDir( GetMainLight().direction));
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);
				
				float3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap, i.uv.zw));
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

				float3 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv.xy).rgb *  _Color;
				
				float3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
				
			 	float3 diffuse =  LightColor * albedo * max(0, dot(bump, lightDir));
			 	
			 	float3 halfDir = normalize(lightDir + viewDir);
			 	float3 specular =  LightColor * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);
				half atten = GetMainLight(TransformWorldToShadowCoord(worldPos)).shadowAttenuation;

		        half3 color = ambient + (diffuse + specular) * atten;
				//��������Դ����

				#ifdef _AdditionalLights
				int lightCount = GetAdditionalLightsCount();
				//��ȡAddLight��������ID
				half4 shadowMask = unity_ProbesOcclusion;//��ȡshadowMask
				for(int index = 0; index < lightCount; index++){
                        Light light = GetAdditionalLight(index, worldPos,shadowMask);     
				//��ȡ�����ĸ���Դ����λ��
				
                        half3 diffuseAdd = light.color*albedo * max(0, dot(bump, light.direction));
						half3 halfDir = normalize(light.direction + viewDir);
                        half3 specularAdd = light.color * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);
				//���㸱��Դ�ĸ߹���ɫ
						color += (diffuseAdd + specularAdd)*light.shadowAttenuation * light.distanceAttenuation;
                        //���浥��ɫ�����¼������ɫ
				}
			#endif

				return float4(color, 1.0);
			}

			ENDHLSL
		}
		pass
			{
				Tags { "LightMode" = "ShadowCaster" }
				Cull Off
				ZWrite On
				ZTest LEqual
				HLSLPROGRAM
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
				#pragma shader_feature _ALPHATEST_ON
            
				#pragma vertex vert
				#pragma fragment frag

				half3 _LightDirection;

				struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
                float4 tangent : TANGENT;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};

			v2f vert(a2v i){
                v2f o;
                float3 worldPos = TransformObjectToWorld(i.vertex.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(i.normal);
                o.pos = TransformWorldToHClip(ApplyShadowBias(worldPos, worldNormal, _LightDirection));
                //��Ӱר�òü��ռ�����

                #if UNITY_REVERSED_Z
                    o.pos.z = min(o.pos.z, o.pos.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    o.pos.z = max(o.pos.z, o.pos.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                //�ж��Ƿ���DirectXƽ̨�������Ƿ�ת����

                return o;
            
            }

            half4 frag(v2f i): SV_Target{

                return 0;
            }
            
            ENDHLSL

			}
    }
	FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}
