shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Posterization - reduces colors to simulate limited paint palette
uniform int color_levels : hint_range(2, 16) = 6;
uniform float noise_dither : hint_range(0.0, 0.1) = 0.02; // Adds subtle noise to prevent harsh banding

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Add subtle noise dither before quantizing
	float dither = (hash(SCREEN_UV * 1000.0) - 0.5) * noise_dither;
	
	// Quantize each channel
	float levels = float(color_levels);
	vec3 posterized = floor((tex.rgb + dither) * levels) / (levels - 1.0);
	posterized = clamp(posterized, 0.0, 1.0);
	
	COLOR = vec4(posterized, tex.a);
}
