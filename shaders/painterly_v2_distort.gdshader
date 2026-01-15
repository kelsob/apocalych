shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Brush stroke distortion - warps UV coordinates with noise
uniform float distortion_strength : hint_range(0.0, 0.02) = 0.003;
uniform float distortion_scale : hint_range(1.0, 50.0) = 15.0;
uniform float time_speed : hint_range(0.0, 1.0) = 0.0; // 0 for static

// Simple noise function
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * time_speed;
	
	// Offset UV based on noise
	float offset_x = noise(uv * distortion_scale + t) * 2.0 - 1.0;
	float offset_y = noise(uv * distortion_scale + 100.0 + t) * 2.0 - 1.0;
	
	vec2 distorted_uv = uv + vec2(offset_x, offset_y) * distortion_strength;
	
	COLOR = texture(SCREEN_TEXTURE, distorted_uv);
}
