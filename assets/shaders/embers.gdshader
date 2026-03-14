shader_type canvas_item;

// How many spark slots — keep under 100 for performance
uniform int   count      = 60;
// How fast they drift upward
uniform float speed      = 1.20;
// How much they sway side to side while drifting
uniform float sway       = 0.20;
// Overall brightness
uniform float brightness = 3.00;

uniform vec4 col_hot  : source_color = vec4(1.00, 0.96, 0.72, 1.0); // white-yellow core
uniform vec4 col_warm : source_color = vec4(1.00, 0.48, 0.06, 1.0); // orange
uniform vec4 col_cool : source_color = vec4(0.50, 0.08, 0.01, 1.0); // deep ember red

float h1(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
	vec2 uv  = UV;
	float t  = TIME * speed;
	vec3 col = vec3(0.0);

	for (int i = 0; i < 100; i++) {
		if (i >= count) break;
		float fi = float(i);

		// Each slot has its own random lifetime so respawns are staggered
		float life         = 0.5 + h1(fi * 13.73) * 2.5;
		float phase_offset = h1(fi * 7.31);

		// Generation increments every time this slot's spark dies
		float gen   = floor((t + phase_offset * life) / life);
		// Phase 0→1 within the current generation's lifetime
		float phase = fract((t  + phase_offset * life) / life);

		// Respawn position — different every generation
		float bx = h1(fi * 3.17 + gen * 19.43);
		float by = h1(fi * 5.73 + gen * 11.17);

		// Drift upward + sinusoidal sway
		float sx  = sin((TIME + h1(fi)) * (1.8 + h1(fi * 2.1) * 3.0)) * sway * 0.06;
		vec2  pos = vec2(bx + sx, by - phase * 0.28);

		// Fade envelope: quick flash in, slow fade out
		float fade    = pow(sin(phase * 3.14159), 0.55);
		// Independent high-frequency flicker per spark
		float flicker = 0.45 + 0.55 * sin(TIME * (7.0 + h1(fi) * 22.0) + fi * 2.39);

		// --- Pixel-exact distance ---
		// Dividing by SCREEN_PIXEL_SIZE converts UV distance into pixel distance.
		// Chebyshev (max of abs x,y) gives square pixel clusters, not circles.
		vec2  diff = (uv - pos) / SCREEN_PIXEL_SIZE;
		float d    = max(abs(diff.x), abs(diff.y));

		// Pixel radius: 0.5–2.0 → appears as 1–4 pixel wide square cluster
		float px_r = 0.5 + h1(fi * 2.3 + gen * 7.7) * 1.5;

		// Hard edge — no gaussian falloff, just a clean pixel hit
		float hit = step(d, px_r);

		// Colour varies per slot/generation: mix along hot→warm→cool
		float heat = h1(fi * 4.11 + gen * 3.31);
		vec3  sc   = mix(col_cool.rgb, col_warm.rgb, heat);
		sc         = mix(sc, col_hot.rgb, heat * heat);

		col += sc * hit * fade * flicker * brightness;
	}

	// Alpha from luminance — works perfectly with Add blend mode
	float alpha = clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
