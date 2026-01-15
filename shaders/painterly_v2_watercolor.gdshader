shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Watercolor effect - color bleeding with edge darkening
uniform float bleed_amount : hint_range(0.0, 5.0) = 2.0;
uniform float edge_darken : hint_range(0.0, 0.5) = 0.15;
uniform float color_variation : hint_range(0.0, 0.1) = 0.03;
uniform float paper_texture : hint_range(0.0, 0.2) = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	
	// Directional blur based on noise (simulates pigment flow)
	float angle = noise(SCREEN_UV * 20.0) * 6.28;
	vec2 blur_dir = vec2(cos(angle), sin(angle)) * pixel_size * bleed_amount;
	
	vec4 color = vec4(0.0);
	color += texture(SCREEN_TEXTURE, SCREEN_UV) * 0.4;
	color += texture(SCREEN_TEXTURE, SCREEN_UV + blur_dir) * 0.2;
	color += texture(SCREEN_TEXTURE, SCREEN_UV - blur_dir) * 0.2;
	color += texture(SCREEN_TEXTURE, SCREEN_UV + blur_dir * 0.5) * 0.1;
	color += texture(SCREEN_TEXTURE, SCREEN_UV - blur_dir * 0.5) * 0.1;
	
	// Edge detection for darkening
	float center = dot(texture(SCREEN_TEXTURE, SCREEN_UV).rgb, vec3(0.299, 0.587, 0.114));
	float around = 0.0;
	around += dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(1.0, 0.0) * pixel_size * 2.0).rgb, vec3(0.299, 0.587, 0.114));
	around += dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-1.0, 0.0) * pixel_size * 2.0).rgb, vec3(0.299, 0.587, 0.114));
	around += dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, 1.0) * pixel_size * 2.0).rgb, vec3(0.299, 0.587, 0.114));
	around += dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, -1.0) * pixel_size * 2.0).rgb, vec3(0.299, 0.587, 0.114));
	around /= 4.0;
	
	float edge = abs(center - around);
	color.rgb *= 1.0 - edge * edge_darken * 10.0;
	
	// Subtle color variation
	float variation = (noise(SCREEN_UV * 50.0) - 0.5) * color_variation;
	color.rgb += variation;
	
	// Paper texture (subtle grain)
	float paper = (noise(SCREEN_UV * 200.0) - 0.5) * paper_texture;
	color.rgb += paper;
	
	COLOR = color;
}
