#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

float s;// random seed

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
/*
返回一个局部坐标系的位置
参数 pdf 是采样的概率，参数 s 是随机数状态
*/
vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}
// 透视除法
vec4 Project(vec4 a) {
  return a / a.w;
}
// gl_position.w
// 线性深度、世界空间深度、点到相机的线性距离，透视除法之前
float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*float linearize_depth(float d,float zNear,float zFar)
{
    float z_n = 2.0 * d - 1.0;
    return 2.0 * zNear * zFar / (zFar + zNear - z_n * (zFar - zNear));
}

float RestoreLinearDepth(float d){
  return linearize_depth(d, 1e-3, 1000.0);
}*/
/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

/*float GetScreenSpaceDepth(vec3 posWorld) {
  float depth = Project(vWorldToScreen * vec4(posWorld, 1.0)).z * 0.5 + 0.5;
  return depth;
}*/

// gl_Position.w 线性深度
float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

// 已经通过简单地比较深度得到了可见性信息，并保存到了贴图中
float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

// get albedo
vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 * 着色点位于 uv 处得到的光源的辐射度
 gbuffer里已有深度、法线、世界坐标、albedo
 根据这些信息简单地计算漫反射光照 albedo * L(i) * dot(N, L) / pi
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 N = normalize(GetGBufferNormalWorld(uv));
  vec3 albedo = GetGBufferDiffuse(uv);
  vec3 L = albedo * max(0.0, dot(N, wi)) * INV_PI;
  return L;
}

#define SAMPLE_NUM 25
#define RAY_MARCH_SAMPLE_NUM 100
/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) { 
  float visible = GetGBufferuShadow(uv);
  vec3 Le = visible * uLightRadiance;
  return Le;
}

/* 射线公式 ro + distance * rd
步长是怎么决定的？步进在相机空间，相机(far plane - near plane)/samples, 步长数量直接影响走样
透视除法之后，z在[-1,1]之间
这里没有reserved-z，分辨率?
*/
bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  float dis = 0.0;
  float maxLength = 250.0;
  float step = 0.05;//maxLength / float(RAY_MARCH_SAMPLE_NUM);
  for(int i = 1; i <= RAY_MARCH_SAMPLE_NUM; i++){
    vec3 pos = ori + dis * dir;
    vec2 uv = GetScreenCoordinate(pos);
    if(uv.x < 0.0 || uv.y < 0.0)  return false;
    float depth = GetGBufferDepth(uv);   
    float z = GetDepth(pos); 
    if(z - depth > 1e-3){// hit
      hitPos = pos;
      return true;
    }    
    dis += step;
  }
  return false;
}

void GenerateSamples(out vec3 samples[SAMPLE_NUM], out float pdfs[SAMPLE_NUM]){
  for(int i = 0; i < SAMPLE_NUM; i++){
    float pdf; 
    //float r = float(i);
    //float rr = Rand1(r);
    Rand1(s);
  //  samples[i] = normalize(SampleHemisphereUniform(s, pdf));
    samples[i] = normalize(SampleHemisphereCos(s, pdf));
    pdfs[i] = pdf;
  }
}

vec3 tanToWorld(vec3 worldN, vec3 tanV){
  vec3 T, B;
  LocalBasis(worldN, T, B);
  mat3 TBN = mat3(normalize(T), normalize(B), worldN);
  return normalize(TBN * tanV);
}

vec3 EvalInDirectionalLight(vec3 pos, vec3 N, vec2 uv0){
  vec3 hitPos= vec3(0.0);
  vec3 L = vec3(0.0);
  vec3 dir;

  vec3 samples[SAMPLE_NUM];
  float pdfs[SAMPLE_NUM];
  GenerateSamples(samples, pdfs);

  for(int i = 0; i < SAMPLE_NUM; i++){      
    dir = tanToWorld(N, samples[i]); 
    if(RayMarch(pos, dir, hitPos)){
      vec2 uv = GetScreenCoordinate(hitPos);
      //vec3 N = normalize(GetGBufferNormalWorld(uv));
      //L += directL / pdfs[i] * EvalDiffuse(dir, vec3(0.0), uv) * EvalDirectionalLight(uv);//* GetGBufferDiffuse(uv);//EvalDirectionalLightWithoutShadow(uv);
      L += EvalDiffuse(dir, vec3(0.), uv0) / pdfs[i] * EvalDiffuse(uLightDir, vec3(0.), uv) * EvalDirectionalLight(uv);
      //L += GetGBufferDiffuse(uv);
    } 
  }
  return L / float(SAMPLE_NUM);
}

vec3 Test(vec2 uv){
  vec3 N = GetGBufferNormalWorld(uv);
  vec3 pos = vPosWorld.xyz;//GetGBufferPosWorld(uv);

  // for test specular reflection
  vec3 posWorld = GetGBufferPosWorld(uv);
  vec3 V = normalize(uCameraPos - posWorld);
  vec3 R = normalize(reflect(-V, N));
  //return R;
  vec3 dir = vec3(0.0);
  vec3 hitPos= vec3(0.0);
  if(RayMarch(pos, R, hitPos)){
    //return vec3(0.5);
    vec2 uv = GetScreenCoordinate(hitPos);
    if(uv.x < 0.0 || uv.y < 0.0)  return vec3(0.0);
    return GetGBufferDiffuse(uv);
  }
  return vec3(0.0);
}

 
void main() {
  s = InitRand(gl_FragCoord.xy);

  vec3 L = vec3(0.0);

  vec2 uv = GetScreenCoordinate(vPosWorld.xyz);
  // vec3 pos = GetGBufferPosWorld(uv); wrong
  vec3 N = normalize(GetGBufferNormalWorld(uv));

  L = EvalDiffuse(uLightDir, vec3(0.0), uv) * EvalDirectionalLight(uv);

  L += EvalInDirectionalLight(vPosWorld.xyz, N, uv);
  // L = EvalInDirectionalLight(uv);
 // L = Test(uv);
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}
