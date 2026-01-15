shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Kuwahara filter - creates oil-paint-like flat regions with preserved edges
// Samples 4 quadrants around each pixel and picks the one with lowest variance
uniform int radius : hint_range(1, 6) = 3;

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	
	// Sample 4 quadrants and find the one with minimum variance
	vec3 mean[4];
	float variance[4];
	
	for (int q = 0; q < 4; q++) {
		mean[q] = vec3(0.0);
		variance[q] = 0.0;
	}
	
	float sample_count = float((radius + 1) * (radius + 1));
	
	// Quadrant 0: top-left, 1: top-right, 2: bottom-left, 3: bottom-right
	for (int i = -radius; i <= 0; i++) {
		for (int j = -radius; j <= 0; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			mean[0] += c;
		}
	}
	for (int i = 0; i <= radius; i++) {
		for (int j = -radius; j <= 0; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			mean[1] += c;
		}
	}
	for (int i = -radius; i <= 0; i++) {
		for (int j = 0; j <= radius; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			mean[2] += c;
		}
	}
	for (int i = 0; i <= radius; i++) {
		for (int j = 0; j <= radius; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			mean[3] += c;
		}
	}
	
	for (int q = 0; q < 4; q++) {
		mean[q] /= sample_count;
	}
	
	// Calculate variance for each quadrant
	for (int i = -radius; i <= 0; i++) {
		for (int j = -radius; j <= 0; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			vec3 diff = c - mean[0];
			variance[0] += dot(diff, diff);
		}
	}
	for (int i = 0; i <= radius; i++) {
		for (int j = -radius; j <= 0; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			vec3 diff = c - mean[1];
			variance[1] += dot(diff, diff);
		}
	}
	for (int i = -radius; i <= 0; i++) {
		for (int j = 0; j <= radius; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			vec3 diff = c - mean[2];
			variance[2] += dot(diff, diff);
		}
	}
	for (int i = 0; i <= radius; i++) {
		for (int j = 0; j <= radius; j++) {
			vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(i), float(j)) * pixel_size).rgb;
			vec3 diff = c - mean[3];
			variance[3] += dot(diff, diff);
		}
	}
	
	// Pick quadrant with minimum variance
	int min_idx = 0;
	float min_var = variance[0];
	for (int q = 1; q < 4; q++) {
		if (variance[q] < min_var) {
			min_var = variance[q];
			min_idx = q;
		}
	}
	
	COLOR = vec4(mean[min_idx], 1.0);
}
