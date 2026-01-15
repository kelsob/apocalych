shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Blur radius in pixels
uniform int blur_radius : hint_range(1, 16) = 4;

// Blur intensity/sigma
uniform float blur_strength : hint_range(0.5, 10.0) = 2.0;

// Overall blur opacity (1.0 = full blur, 0.0 = no effect)
uniform float blur_opacity : hint_range(0.0, 1.0) = 1.0;

float gaussian_weight(float i, float sigma) {
	return exp(-0.5 * (i * i) / (sigma * sigma));
}

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;

	// Build kernel weights
	float kernel[17]; // max radius 16 + center
	float sum = 0.0;
	for (int i = 0; i <= blur_radius; i++) {
		kernel[i] = gaussian_weight(float(i), blur_strength);
		sum += i == 0 ? kernel[i] : 2.0 * kernel[i];
	}
	for (int i = 0; i <= blur_radius; i++) {
		kernel[i] /= sum;
	}

	// Two-pass separable blur combined
	vec4 blur_color = vec4(0.0);

	for (int x = -blur_radius; x <= blur_radius; x++) {
		for (int y = -blur_radius; y <= blur_radius; y++) {
			float weight = kernel[abs(x)] * kernel[abs(y)];
			vec2 offset = vec2(float(x), float(y)) * pixel_size;
			blur_color += texture(SCREEN_TEXTURE, uv + offset) * weight;
		}
	}

	// Mix with original based on opacity
	vec4 original = texture(SCREEN_TEXTURE, uv);
	COLOR = mix(original, blur_color, blur_opacity);
}
