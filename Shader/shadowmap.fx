#if SHADOW_QUALITY == 1
#   define SHADOW_MAP_SIZE 1024
#elif SHADOW_QUALITY == 2
#   define SHADOW_MAP_SIZE 2048
#else
#   define SHADOW_MAP_SIZE 4096
#endif

#if defined(ENABLE_HARD_SHADOW) && ENABLE_HARD_SHADOW > 0
#   define NUM_SHADOW_BLUR     4
#   define SHADOW_WEIGHT       2
#else
#   define NUM_SHADOW_BLUR     8
#   define SHADOW_WEIGHT       1
#endif

texture ShadowMap : OFFSCREENRENDERTARGET <
    string Description = "Shadow Rendering for ray";
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "A16B16G16R16F";
    float4 ClearColor = { 1, 0, 0, 0 };
    float ClearDepth = 1.0;
    int MipLevels = 1;
    string DefaultEffect =
        "self = hide;"
        "ray_controller.pmx=hide;"
        "skybox*.*=hide;"
        "PointLight*.*=hide;"
        "SpotLight*.*=hide;"
        "SphereLight*.*=hide;"
        "TubeLight*.* =hide;"
        "RectangleLight*.*=shadow/shadow.fx;"
        "LED*.*=shadow/shadow.fx;"
        "*.pmx=shadow/shadow.fx;"
        "*.pmd=shadow/shadow.fx;"
        "*.x=hide;";
>;

sampler ShadowSamp = sampler_state {
    texture = <ShadowMap>;
    MinFilter = NONE;   MagFilter = NONE;   MipFilter = NONE;
    AddressU  = CLAMP;  AddressV = CLAMP;
};

shared texture LightMap : OFFSCREENRENDERTARGET <
    string Description = "Lightspace Depth for ray";
    int Width = SHADOW_MAP_SIZE;
    int Height = SHADOW_MAP_SIZE;
    string Format = "R32F";
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    int MipLevels = 1;
    string DefaultEffect =
        "self = hide;"
        "ray_controller.pmx=hide;"
        "skybox*.*=hide;"
        "PointLight*.*=hide;"
        "SpotLight*.*=hide;"
        "SphereLight*.*=hide;"
        "TubeLight*.* =hide;"
        "LED*.*=shadow/lightdepth.fx;"
        "RectangleLight*.*=shadow/lightdepth.fx;"
        "*.pmx=shadow/lightdepth.fx;"
        "*.pmd=shadow/lightdepth.fx;"
        "*.x=hide;";
>;

float CalcShadowBlurWeight(float d0, float d1, float depthRate)
{
    float dd = (d0 - d1) * depthRate;
    return exp(-dd*dd);
}

static const float BlurWeight[] = {
    0.0920246,
    0.0902024,
    0.0849494,
    0.0768654,
    0.0668236,
    0.0558158,
    0.0447932,
    0.0345379,
};

void ShadowMappingVS(
    in float4 Position : POSITION,
    in float4 Texcoord : TEXCOORD,
    out float4 oTexcoord : TEXCOORD0,
    out float4 oPosition : SV_Position)
{
    oPosition = Position;
    oTexcoord = Texcoord + ViewportOffset.xyxy;
}

float4 ShadowMappingPS(float2 coord : TEXCOORD0, uniform sampler2D source, uniform float2 offset) : COLOR
{
    float3 center = tex2D(source, coord).xyz;
    float centerDepth = center.z;
    float depthRate = 100.0 / centerDepth;

    float3 sum = float3(center.xy, 1) * BlurWeight[0];

    [unroll]
    for(int i = 1; i < NUM_SHADOW_BLUR; i++)
    {
        float3 shadowDepthP, shadowDepthN;
        shadowDepthP = tex2D(source, coord + offset * i).xyz;
        shadowDepthN = tex2D(source, coord - offset * i).xyz;
        float wp = CalcShadowBlurWeight(shadowDepthP.z, centerDepth, depthRate);
        float wn = CalcShadowBlurWeight(shadowDepthN.z, centerDepth, depthRate);
        float w = BlurWeight[i * SHADOW_WEIGHT];
        sum += float3(shadowDepthP.xy * wp + shadowDepthN.xy * wn, wp + wn) * w;
    }

    return float4(sum.xy / sum.z, centerDepth, 1);
}
