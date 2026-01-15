shader_type canvas_item;
render_mode unshaded;

// Painterly/asymmetric shader to make lines look hand-drawn
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float edge_distortion : hint_range(0.0, 0.02) = 0.005;
uniform float color_variation : hint_range(0.0, 0.1) = 0.03;
uniform float texture_overlay_strength : hint_range(0.0, 0.5) = 0.15;
uniform float texture_scale : hint_range(1.0, 20.0) = 8.0;

// Simple noise function
float noise(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise
float smooth_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Add edge distortion for asymmetric/hand-drawn look
	vec2 distortion = vec2(
		smooth_noise(uv * texture_scale) - 0.5,
		smooth_noise((uv + vec2(0.5, 0.3)) * texture_scale) - 0.5
	) * edge_distortion;
	
	vec2 distorted_uv = uv + distortion;
	vec4 screen_color = texture(screen_texture, distorted_uv);
	
	// Add slight color variation for painterly effect
	vec3 color_var = vec3(
		smooth_noise(uv * texture_scale * 2.0) - 0.5,
		smooth_noise((uv + vec2(0.3, 0.7)) * texture_scale * 2.0) - 0.5,
		smooth_noise((uv + vec2(0.7, 0.3)) * texture_scale * 2.0) - 0.5
	) * color_variation;
	
	vec3 final_color = screen_color.rgb + color_var;
	
	// Add texture overlay for paper texture effect
	float texture_noise = smooth_noise(uv * texture_scale * 3.0);
	final_color = mix(final_color, final_color * texture_noise, texture_overlay_strength);
	
	COLOR = vec4(final_color, screen_color.a);
}
