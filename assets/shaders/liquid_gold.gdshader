shader_type canvas_item;

// ── Motion ────────────────────────────────────────────────────────────────────
uniform float speed          : hint_range(0.0, 3.0)  = 0.30;
uniform float scale          : hint_range(0.5, 8.0)  = 2.50;
uniform float warp           : hint_range(0.0, 6.0)  = 3.00;

// ── Appearance ────────────────────────────────────────────────────────────────
uniform float contrast       : hint_range(0.5, 2.5)  = 1.30;  // lowered — less sharpening
uniform float shimmer        : hint_range(0.0, 1.0)  = 0.80;
uniform float vignette       : hint_range(0.0, 2.0)  = 0.55;

// ── Gold Palette ──────────────────────────────────────────────────────────────
uniform vec4  col_shadow  : source_color = vec4(0.09, 0.03, 0.00, 1.0);
uniform vec4  col_amber   : source_color = vec4(0.34, 0.13, 0.01, 1.0);
uniform vec4  col_gold    : source_color = vec4(0.75, 0.46, 0.04, 1.0);
uniform vec4  col_bright  : source_color = vec4(1.00, 0.82, 0.18, 1.0);
uniform vec4  col_glint   : source_color = vec4(1.00, 0.97, 0.86, 1.0);

// ── Gradient Noise ────────────────────────────────────────────────────────────
// Value noise interpolates scalar corner values → visible C1 kinks at cell edges.
// Gradient noise (IQ/Perlin style) interpolates dot-products of random gradients
// with offset vectors → smooth everywhere, zero grid-line artifacts.

vec2 ghash(vec2 p) {
	// Two independent dot products fed through sin give uncorrelated gradient dirs.
	p = vec2(dot(p, vec2(127.1, 311.7)),
	         dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic smooth — C2 continuous, no derivative kinks
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	float a = dot(ghash(i),               f);
	float b = dot(ghash(i + vec2(1, 0)),  f - vec2(1, 0));
	float c = dot(ghash(i + vec2(0, 1)),  f - vec2(0, 1));
	float d = dot(ghash(i + vec2(1, 1)),  f - vec2(1, 1));

	// Output range is roughly −0.7..0.7 — normalise to 0..1
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.7071 + 0.5;
}

// fBm with rotation between octaves — breaks any residual axis alignment
float fbm(vec2 p, int oct) {
	float val = 0.0;
	float amp = 0.5;
	mat2  rot = mat2(vec2(0.8,  0.6),
	                 vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		val += amp * gnoise(p);
		p    = rot * p * 2.0;
		amp *= 0.50;
	}
	return val;
}

// ── Gold Color Ramp ───────────────────────────────────────────────────────────

vec3 gold_ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c = col_shadow.rgb;
	c = mix(c, col_amber.rgb,  smoothstep(0.00, 0.30, t));
	c = mix(c, col_gold.rgb,   smoothstep(0.24, 0.64, t));
	c = mix(c, col_bright.rgb, smoothstep(0.54, 0.86, t));
	c = mix(c, col_glint.rgb,  smoothstep(0.82, 1.00, t));
	return c;
}

// ── Main Fragment ─────────────────────────────────────────────────────────────

void fragment() {
	vec2  uv = UV;
	float t  = TIME * speed;
	vec2  p  = uv * scale;

	// Level 1 warp
	vec2 q = vec2(
		fbm(p + vec2(0.00, 0.00) + t * 0.22, 4),
		fbm(p + vec2(3.74, 1.93) + t * 0.18, 4)
	);

	// Level 2 warp — feeds off level 1 for eddies and pooling
	vec2 r = vec2(
		fbm(p + warp * q + vec2(1.70, 9.20) + t * 0.11, 4),
		fbm(p + warp * q + vec2(8.30, 2.80) + t * 0.09, 4)
	);

	// Final field
	float base = fbm(p + warp * r + t * 0.04, 5);

	// Gentle S-curve contrast — smoothstep avoids the hard clipping that
	// pow() produces near 0 and 1 when contrast is pushed
	base = clamp(base * contrast - (contrast - 1.0) * 0.5, 0.0, 1.0);
	base = smoothstep(0.0, 1.0, base);

	vec3 col = gold_ramp(base);

	// ── Specular Glints ──────────────────────────────────────────────────────
	// Peak glints: natural crests of the already-warped field, no new noise needed
	float peak_glint = pow(base, 7.0);

	// Drifting sparkles: low-frequency fbm (gradient, no grid lines) thresholded
	float s1   = fbm(uv * 4.5 + vec2( t * 0.36,  t * 0.13), 4);
	float s2   = fbm(uv * 6.5 + vec2(-t * 0.19,  t * 0.28), 4);
	float spark = pow(clamp((s1 * s2 - 0.22) * 3.0, 0.0, 1.0), 4.0);

	float glints = clamp(peak_glint * 0.55 + spark * 0.70, 0.0, 1.0);
	col = mix(col, col_glint.rgb, glints * shimmer);

	// ── Elliptical Vignette ──────────────────────────────────────────────────
	vec2  vig_uv = uv - 0.5;
	float v = 1.0 - dot(vig_uv * vec2(0.9, 1.1), vig_uv * vec2(0.9, 1.1)) * 2.5 * vignette;
	col *= clamp(v, 0.12, 1.0);

	COLOR = vec4(col, 1.0);
}
