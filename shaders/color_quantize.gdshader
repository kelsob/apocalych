shader_type canvas_item;
render_mode unshaded;

// Screen texture - this is what we're post-processing
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Controls how many discrete color levels per channel
// Lower = fewer colors, more retro/pixel-art
// 4 levels = 64 colors (4×4×4)
// 5 levels = 125 colors (5×5×5)
// 6 levels = 216 colors (6×6×6)
// 8 levels = 512 colors (8×8×8)
uniform int color_levels : hint_range(3, 16) = 6;

// Optional: dithering to smooth out banding (Bayer matrix)
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3;

// 4x4 Bayer dithering matrix for ordered dithering
const mat4 bayer_matrix = mat4(
    vec4(0.0, 8.0, 2.0, 10.0),
    vec4(12.0, 4.0, 14.0, 6.0),
    vec4(3.0, 11.0, 1.0, 9.0),
    vec4(15.0, 7.0, 13.0, 5.0)
) / 16.0;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    
    // Quantize each color channel to discrete levels
    float levels = float(color_levels);
    
    if (enable_dithering && color_levels > 4) {
        // Only use dithering for higher color counts (smoother look)
        // For low color counts, dithering defeats the purpose
        ivec2 pixel_pos = ivec2(FRAGCOORD.xy) % 4;
        float dither = bayer_matrix[pixel_pos.x][pixel_pos.y];
        
        // Add dither offset scaled by strength
        float dither_offset = (dither - 0.5) * dither_strength / levels;
        color.rgb += vec3(dither_offset);
        
        // Round to nearest level (with dithering influence)
        color.r = floor(color.r * levels + 0.5) / levels;
        color.g = floor(color.g * levels + 0.5) / levels;
        color.b = floor(color.b * levels + 0.5) / levels;
    } else {
        // Pure floor quantization - creates harsh, visible bands
        // This is what gives the "jumping" effect you want
        color.r = floor(color.r * levels) / levels;
        color.g = floor(color.g * levels) / levels;
        color.b = floor(color.b * levels) / levels;
    }
    
    // Clamp to valid range
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    COLOR = color;
}
