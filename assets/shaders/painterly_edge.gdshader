shader_type canvas_item;

/// Match to image width ÷ height
uniform float aspect     : hint_range(0.3, 3.0)  = 1.33;
/// Where the edge zone begins
uniform float edge_start : hint_range(0.0, 0.9)  = 0.42;
/// Width of the transition band
uniform float softness   : hint_range(0.02, 0.7) = 0.38;
/// How wildly the edge warps
uniform float distortion : hint_range(0.0, 0.55) = 0.22;
/// Animation speed
uniform float speed      : hint_range(0.0, 2.0)  = 0.18;
/// How intensely the edge burns — 0 = plain fade, 1 = full char
uniform float burn       : hint_range(0.0, 1.0)  = 0.90;

// ── Burnt parchment palette ───────────────────────────────────────────────────
uniform vec4 col_scorch : source_color = vec4(0.62, 0.28, 0.04, 1.0); // scorched amber
uniform vec4 col_ember  : source_color = vec4(0.42, 0.10, 0.01, 1.0); // deep ember red
uniform vec4 col_char   : source_color = vec4(0.05, 0.02, 0.00, 1.0); // charcoal black

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

	// Elliptical distance from centre
	vec2  c   = (UV - 0.5) * vec2(aspect, 1.0);
	float rad = length(c);

	// Two-pass domain warp for organic painterly edges
	vec2 warp_uv = UV * 3.5 + vec2(t * 0.15, t * 0.09);
	vec2 warp = vec2(
		fbm(warp_uv,                   4),
		fbm(warp_uv + vec2(5.2, 1.7), 4)
	) - 0.5;

	vec2 warp2_uv = UV * 2.8 + warp * 1.8 + vec2(t * 0.07, t * 0.12);
	vec2 warp2 = vec2(
		fbm(warp2_uv,                  3),
		fbm(warp2_uv + vec2(3.1, 8.4), 3)
	) - 0.5;

	float eff_rad = rad + dot(warp2, normalize(c + vec2(0.001))) * distortion;

	// edge_t: 0 = inner edge boundary, 1 = fully transparent outer edge
	float edge_t = clamp((eff_rad - edge_start) / max(softness, 0.001), 0.0, 1.0);

	// ── Burnt parchment ───────────────────────────────────────────────────────
	// Extra noise to make the burn ragged and irregular — independent of the
	// main warp so it has its own charred texture character.
	// Slow drift so it feels like smouldering rather than animated fire.
	float burn_noise = fbm(UV * 7.0 + warp2 * 0.6 + vec2(t * 0.04, t * 0.03), 4);

	// Shift the edge position by noise so the burn boundary is never clean
	float noisy_t = clamp(edge_t + (burn_noise - 0.5) * 0.40, 0.0, 1.0);

	// Three overlapping zones from inside out:
	//   scorch (warm amber) → ember (deep red-orange) → char (near black)
	float scorch_amt = smoothstep(0.08, 0.45, noisy_t);
	float ember_amt  = smoothstep(0.35, 0.68, noisy_t) * (1.0 - smoothstep(0.80, 1.00, noisy_t));
	float char_amt   = smoothstep(0.62, 0.96, noisy_t);

	vec3 col = tex.rgb;
	col = mix(col, col_scorch.rgb, scorch_amt * burn);
	col = mix(col, col_ember.rgb,  ember_amt  * burn);
	col = mix(col, col_char.rgb,   char_amt   * burn);

	// ── Alpha ─────────────────────────────────────────────────────────────────
	float alpha = 1.0 - smoothstep(edge_start, edge_start + softness, eff_rad);

	COLOR = vec4(col, tex.a * clamp(alpha, 0.0, 1.0));
}
