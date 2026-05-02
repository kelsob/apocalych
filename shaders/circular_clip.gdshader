shader_type canvas_item;

uniform vec2 circle_center_uv = vec2(0.5, 0.5);
/// Outer radius in aspect-corrected UV units ([code]~0.5[/code] reaches mid-edge on a square control).
uniform float radius : hint_range(0.0, 1.0) = 0.5;
/// Control width ÷ height ([code]1[/code] if square).
uniform float aspect_ratio : hint_range(0.01, 10.0) = 1.0;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 offset = UV - circle_center_uv;
	offset.x *= aspect_ratio;
	if (length(offset) > radius) {
		discard;
	}
	// Assign the sample — do not multiply incoming COLOR (vertex modulate); CanvasItem applies Modulate after the shader.
	COLOR = tex;
}
