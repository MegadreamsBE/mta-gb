#ifdef PIXEL
uniform vec2 scale;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 texel = texture_coords.xy / scale;
    return texture2D(texture, texel);
}
#endif