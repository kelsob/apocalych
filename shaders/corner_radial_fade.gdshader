shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float corner_fade_distance : hint_range(0.0, 200.0) = 30.0;  // Distance from corner for fade
uniform vec4 corner_color : source_color = vec4(0.612, 0.318, 0.153, 1.0); // #9c5127
uniform float corner_intensity : hint_range(0.0, 1.0) = 0.6;  // Overall intensity of corner effect

void fragment() {
	vec2 uv = SCREEN_UV;

	// Get viewport size in pixels
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;

	// Calculate pixel position
	vec2 pixel_pos = uv * viewport_size;

	// Calculate distance to each corner using radial distance
	float dist_to_corner_tl = length(vec2(pixel_pos.x, pixel_pos.y));
	float dist_to_corner_tr = length(vec2(viewport_size.x - pixel_pos.x, pixel_pos.y));
	float dist_to_corner_bl = length(vec2(pixel_pos.x, viewport_size.y - pixel_pos.y));
	float dist_to_corner_br = length(vec2(viewport_size.x - pixel_pos.x, viewport_size.y - pixel_pos.y));

	// Find minimum distance to any corner
	float min_corner_dist = min(min(dist_to_corner_tl, dist_to_corner_tr), min(dist_to_corner_bl, dist_to_corner_br));

	// Calculate exponential fade factor (1.0 at corner, approaches 0 asymptotically)
	float corner_fade = exp(-min_corner_dist / corner_fade_distance);

	// Apply intensity multiplier
	corner_fade *= corner_intensity;

	// Sample the screen texture
	vec4 screen_color = texture(screen_texture, uv);

	// Blend with corner color based on fade factor
	COLOR = mix(screen_color, corner_color, corner_fade);
}
