shader_type canvas_item;

uniform vec2 shadow_offset_uv = vec2(0.02, 0.08);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;

// 1.0 = no vertical squash, lower = flatter on "ground".
uniform float squash_y : hint_range(0.05, 1.0) = 0.22;
// Side cast amount. Positive = right, negative = left.
uniform float skew_x : hint_range(-1.0, 1.0) = 0.22;

uniform float blur_uv : hint_range(0.0, 0.02) = 0.003;
uniform float fade_start_y : hint_range(0.0, 1.0) = 0.20;
uniform float fade_end_y : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Strict passthrough for sprite pixels.
	// Do NOT multiply by incoming COLOR here, so the shader cannot tint/darken the sprite.
	vec4 base = texture(TEXTURE, UV);

	// Output-space point where we draw the projected shadow.
	vec2 duv = UV - shadow_offset_uv;

	// Inverse projected transform:
	// duv.y = 1 - (1 - sy) * squash_y
	// duv.x = sx + (1 - sy) * skew_x
	float sq = max(squash_y, 0.001);
	float sy = 1.0 - (1.0 - duv.y) / sq;
	float topness = 1.0 - sy; // 0 at sprite base, 1 at sprite top
	float sx = duv.x - topness * skew_x;
	vec2 suv = vec2(sx, sy);

	// Skip sampling outside source UV range.
	float in_bounds = step(0.0, suv.x) * step(suv.x, 1.0) * step(0.0, suv.y) * step(suv.y, 1.0);

	float a0 = texture(TEXTURE, suv).a;
	float a1 = texture(TEXTURE, suv + vec2(blur_uv, 0.0)).a;
	float a2 = texture(TEXTURE, suv + vec2(-blur_uv, 0.0)).a;
	float a3 = texture(TEXTURE, suv + vec2(0.0, blur_uv)).a;
	float a4 = texture(TEXTURE, suv + vec2(0.0, -blur_uv)).a;
	float shape_alpha = ((a0 + a1 + a2 + a3 + a4) / 5.0) * in_bounds;

	// More opacity toward bottom, less toward top.
	float vertical_fade = smoothstep(fade_start_y, fade_end_y, duv.y);
	float shadow_alpha = shape_alpha * shadow_color.a * shadow_strength * vertical_fade;

	// Keep original sprite pixels completely untouched.
	// Draw shadow only where the source texture is transparent.
	if (base.a > 0.0001) {
		COLOR = base;
	} else {
		COLOR = vec4(shadow_color.rgb, shadow_alpha);
	}
}