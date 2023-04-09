texture tex;
float2 scale;

sampler2D texSampler = sampler_state
{
    Texture = <tex>;
    MinFilter = Point;
    MagFilter = Point;
    MipFilter = Point;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4 PS_Upscale(float2 uv : TEXCOORD) : COLOR
{
    float2 texel = uv.xy / scale;
    return tex2Dproj(texSampler, float4(texel, 0, 1));
}

technique Upscale
{
    pass Pass1
    {
        PixelShader = compile ps_2_0 PS_Upscale();
        Sampler[0] = texSampler;
    }
}