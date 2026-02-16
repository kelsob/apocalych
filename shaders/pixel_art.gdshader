shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


// Basic pixelation
uniform float pixel_size : hint_range(1.0, 16.0) = 2.0;

// Palette reduction
uniform bool enable_palette_reduction = true;
uniform int color_depth : hint_range(2, 256) = 32;

// Dithering (classic pixel art technique for gradients)
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.15;

// Color enhancement (makes colors pop)
uniform float saturation : hint_range(0.0, 2.0) = 1.2;
uniform float contrast : hint_range(0.0, 2.0) = 1.1;

// Subtle outline (defines edges better)
uniform bool enable_outline = true;
uniform float outline_thickness : hint_range(0.0, 2.0) = 0.5;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Bayer matrix for dithering
const mat4 bayer_matrix = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
) / 16.0;

float get_bayer(vec2 pos) {
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	return bayer_matrix[y][x];
}

vec3 adjust_saturation(vec3 color, float saturation_factor) {
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), color, saturation_factor);
}

vec3 adjust_contrast(vec3 color, float contrast_factor) {
	return (color - 0.5) * contrast_factor + 0.5;
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixelated_uv = floor(SCREEN_UV * screen_size / pixel_size) * pixel_size / screen_size;
	
	// Sample the texture
	vec4 color = texture(SCREEN_TEXTURE, pixelated_uv);
	
	// Palette reduction
	if (enable_palette_reduction) {
		float levels = float(color_depth);
		
		// Apply dithering before quantization
		if (enable_dithering) {
			vec2 pixel_pos = SCREEN_UV * screen_size / pixel_size;
			float threshold = get_bayer(pixel_pos) - 0.5;
			color.rgb += threshold * dither_strength / levels;
		}
		
		color.r = floor(color.r * levels) / levels;
		color.g = floor(color.g * levels) / levels;
		color.b = floor(color.b * levels) / levels;
	}
	
	// Enhance colors
	color.rgb = adjust_saturation(color.rgb, saturation);
	color.rgb = adjust_contrast(color.rgb, contrast);
	
	// Edge detection for outlines
	if (enable_outline) {
		vec2 offset = pixel_size / screen_size * outline_thickness;
		float edge = 0.0;
		
		// Sample neighbors
		vec4 n = texture(SCREEN_TEXTURE, pixelated_uv + vec2(0.0, offset.y));
		vec4 s = texture(SCREEN_TEXTURE, pixelated_uv - vec2(0.0, offset.y));
		vec4 e = texture(SCREEN_TEXTURE, pixelated_uv + vec2(offset.x, 0.0));
		vec4 w = texture(SCREEN_TEXTURE, pixelated_uv - vec2(offset.x, 0.0));
		
		// Calculate color difference
		float diff = 0.0;
		diff += distance(color.rgb, n.rgb);
		diff += distance(color.rgb, s.rgb);
		diff += distance(color.rgb, e.rgb);
		diff += distance(color.rgb, w.rgb);
		
		edge = smoothstep(0.5, 1.0, diff);
		color.rgb = mix(color.rgb, outline_color.rgb, edge * outline_color.a);
	}
	
	COLOR = color;
}