shader_type canvas_item;

/// Match this to your image's width ÷ height so the oval isn't squashed
uniform float aspect     : hint_range(0.3, 3.0)  = 1.33;
/// How far from centre the edge zone begins (higher = smaller clean area)
uniform float edge_start : hint_range(0.0, 0.9)  = 0.42;
/// How wide the stroke transition band is
uniform float softness   : hint_range(0.02, 0.7) = 0.38;
/// How aggressively noise warps the edge — more = wilder brushstrokes
uniform float distortion : hint_range(0.0, 0.55) = 0.22;
/// Animation speed — the edge slowly breathes and morphs
uniform float speed      : hint_range(0.0, 2.0)  = 0.18;

// ── Gradient noise (no grid-line artifacts) ───────────────────────────────────

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

// ── Main ──────────────────────────────────────────────────────────────────────

void fragment() {
	vec4  tex = texture(TEXTURE, UV);
	float t   = TIME * speed;

	// Elliptical distance from centre, corrected for aspect ratio
	vec2  c   = (UV - 0.5) * vec2(aspect, 1.0);
	float rad = length(c);

	// Domain-warp the UV before sampling the edge noise.
	// This is what gives the edge its organic, curling brushstroke quality —
	// adjacent points get pulled in slightly different directions rather than
	// shifting uniformly, so the boundary looks hand-painted.
	vec2 warp_uv = UV * 3.5 + vec2(t * 0.15, t * 0.09);
	vec2 warp = vec2(
		fbm(warp_uv,                    4),
		fbm(warp_uv + vec2(5.2, 1.7),  4)
	) - 0.5;

	// A second warp pass fed by the first gives more complex, layered strokes
	vec2 warp2_uv = UV * 2.8 + warp * 1.8 + vec2(t * 0.07, t * 0.12);
	vec2 warp2 = vec2(
		fbm(warp2_uv,                   3),
		fbm(warp2_uv + vec2(3.1, 8.4), 3)
	) - 0.5;

	// Distort the effective radius by the warped noise field
	float eff_rad = rad + dot(warp2, normalize(c + vec2(0.001))) * distortion;

	// Smooth alpha ramp over the edge band
	float alpha = 1.0 - smoothstep(edge_start, edge_start + softness, eff_rad);

	COLOR = vec4(tex.rgb, tex.a * clamp(alpha, 0.0, 1.0));
}
