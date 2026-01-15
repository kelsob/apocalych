shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D water_texture : filter_nearest, repeat_enable;
uniform float texture_scale = 0.01;  // UV tiling scale

// Wave animation parameters
uniform float wave_height = 0.8;  // Amplitude of waves (increased for visibility)
uniform float wave_speed = 1.5;   // Speed of animation
uniform float wave_frequency = 0.08;  // Frequency (lower = larger waves)

varying vec3 world_pos;

void vertex() {
	// Calculate world position
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Animate waves using multiple sine layers
	float time = TIME * wave_speed;
	
	// Layer 1: Large slow waves
	float wave1 = sin(world_pos.x * wave_frequency + time) * wave_height;
	
	// Layer 2: Medium waves perpendicular
	float wave2 = cos(world_pos.z * wave_frequency * 1.3 + time * 0.8) * wave_height * 0.6;
	
	// Layer 3: Small diagonal ripples
	float wave3 = sin((world_pos.x + world_pos.z) * wave_frequency * 2.0 + time * 1.5) * wave_height * 0.3;
	
	// Layer 4: Micro ripples
	float wave4 = cos((world_pos.x - world_pos.z) * wave_frequency * 3.0 + time * 2.0) * wave_height * 0.2;
	
	// Apply all wave layers to Y position
	VERTEX.y += wave1 + wave2 + wave3 + wave4;
}

void fragment() {
	// Sample water texture using world-space UVs
	vec2 world_uv = world_pos.xz * texture_scale;
	
	vec4 water_color = texture(water_texture, world_uv);
	
	// Apply slight blue tint
	water_color.rgb *= vec3(0.9, 1.0, 1.1);
	
	ALBEDO = water_color.rgb;
	ROUGHNESS = 0.3;
	METALLIC = 0.0;
	SPECULAR = 0.4;  // Water sheen
}
