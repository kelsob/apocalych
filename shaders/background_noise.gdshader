shader_type canvas_item;
render_mode unshaded;

// Noise shader to add mottled texture to the background
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.15;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform vec3 noise_color : source_color = vec3(0.85, 0.80, 0.75);

void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	
	// Generate noise using screen coordinates
	vec2 noise_uv = SCREEN_UV * noise_scale;
	float noise = fract(sin(dot(noise_uv, vec2(12.9898, 78.233))) * 43758.5453);
	noise = noise * 0.5 + 0.5; // Normalize to 0-1
	
	// Create mottled effect by mixing with noise color
	vec3 mottled_color = mix(screen_color.rgb, noise_color, noise * noise_strength);
	
	COLOR = vec4(mottled_color, screen_color.a);
}
