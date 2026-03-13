shader_type canvas_item;

// ── Motion ─────────────────────────────────────────────────────────────────
uniform float speed           : hint_range(0.0, 3.0) = 0.40;
/// How tightly it spirals — 0 = no vortex, higher = tighter spin
uniform float vortex_strength : hint_range(0.0, 10.0) = 4.50;
/// How fast the spin fades from centre outward — low = whole image rotates,
/// high = tight whirlpool
uniform float vortex_decay    : hint_range(0.5, 10.0) = 3.50;

// ── Detail ──────────────────────────────────────────────────────────────────
uniform float scale           : hint_range(0.5, 8.0) = 2.50;
uniform float warp            : hint_range(0.0, 5.0) = 2.50;
uniform float shimmer         : hint_range(0.0, 1.0) = 0.80;
uniform float vignette        : hint_range(0.0, 2.0) = 0.60;

// ── Gold Palette ─────────────────────────────────────────────────────────────
uniform vec4 col_shadow  : source_color = vec4(0.09, 0.03, 0.00, 1.0);
uniform vec4 col_amber   : source_color = vec4(0.34, 0.13, 0.01, 1.0);
uniform vec4 col_gold    : source_color = vec4(0.75, 0.46, 0.04, 1.0);
uniform vec4 col_bright  : source_color = vec4(1.00, 0.82, 0.18, 1.0);
uniform vec4 col_glint   : source_color = vec4(1.00, 0.97, 0.86, 1.0);

// ── Gradient Noise ────────────────────────────────────────────────────────────

vec2 ghash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(ghash(i),              f);
	float b = dot(ghash(i + vec2(1, 0)), f - vec2(1, 0));
	float c = dot(ghash(i + vec2(0, 1)), f - vec2(0, 1));
	float d = dot(ghash(i + vec2(1, 1)), f - vec2(1, 1));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.7071 + 0.5;
}

float fbm(vec2 p, int oct) {
	float val = 0.0;
	float amp = 0.5;
	mat2  rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		val += amp * gnoise(p);
		p    = rot * p * 2.0;
		amp *= 0.5;
	}
	return val;
}

// ── Gold Ramp ─────────────────────────────────────────────────────────────────

vec3 gold_ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c = col_shadow.rgb;
	c = mix(c, col_amber.rgb,  smoothstep(0.00, 0.30, t));
	c = mix(c, col_gold.rgb,   smoothstep(0.24, 0.64, t));
	c = mix(c, col_bright.rgb, smoothstep(0.54, 0.86, t));
	c = mix(c, col_glint.rgb,  smoothstep(0.82, 1.00, t));
	return c;
}

// ── Main ──────────────────────────────────────────────────────────────────────

void fragment() {
	vec2  uv = UV;
	float t  = TIME * speed;

	// ── Vortex transform ──────────────────────────────────────────────────────
	// Convert to polar, add a time-driven spin that decays exponentially outward.
	// Inner ring spins fastest; outer edges barely move — classic vortex/whirlpool.
	vec2  centered = uv - 0.5;
	float rad      = length(centered);
	float ang      = atan(centered.y, centered.x);

	float spin = vortex_strength * t * exp(-rad * vortex_decay);
	ang += spin;

	// Back to Cartesian UV — this is the vortex-warped coordinate
	vec2 swirl_uv = vec2(cos(ang), sin(ang)) * rad + 0.5;
	vec2 p        = swirl_uv * scale;

	// ── Domain warp on top of the vortex ─────────────────────────────────────
	// Adds organic turbulence so it reads as liquid rather than a clean rotation.
	vec2 q = vec2(
		fbm(p + vec2(0.00, 0.00) + t * 0.14, 4),
		fbm(p + vec2(3.74, 1.93) + t * 0.11, 4)
	);

	vec2 r = vec2(
		fbm(p + warp * q + vec2(1.70, 9.20) + t * 0.07, 4),
		fbm(p + warp * q + vec2(8.30, 2.80) + t * 0.06, 4)
	);

	float base = fbm(p + warp * r + t * 0.03, 5);

	// Gentle S-curve contrast
	base = smoothstep(0.0, 1.0, clamp(base * 1.35 - 0.175, 0.0, 1.0));

	vec3 col = gold_ramp(base);

	// ── Specular glints ───────────────────────────────────────────────────────
	// Peak glints follow the natural crests of the vortex field
	float peak_glint = pow(base, 7.0);

	// Drifting sparkles also rotate with the swirl UV
	float s1    = fbm(swirl_uv * 4.5 + vec2( t * 0.36,  t * 0.13), 4);
	float s2    = fbm(swirl_uv * 6.5 + vec2(-t * 0.19,  t * 0.28), 4);
	float spark = pow(clamp((s1 * s2 - 0.22) * 3.0, 0.0, 1.0), 4.0);

	col = mix(col, col_glint.rgb, clamp(peak_glint * 0.55 + spark * 0.70, 0.0, 1.0) * shimmer);

	// ── Elliptical vignette ───────────────────────────────────────────────────
	vec2  vig = uv - 0.5;
	float v   = 1.0 - dot(vig * vec2(0.9, 1.1), vig * vec2(0.9, 1.1)) * 2.5 * vignette;
	col      *= clamp(v, 0.12, 1.0);

	COLOR = vec4(col, 1.0);
}
