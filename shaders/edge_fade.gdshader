shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float fade_distance : hint_range(0.0, 100.0) = 16.0;
uniform vec4 edge_color : source_color = vec4(0.612, 0.318, 0.153, 1.0); // #9c5127

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Get viewport size in pixels
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
	
	// Calculate pixel position
	vec2 pixel_pos = uv * viewport_size;
	
	// Calculate distance to each edge in pixels
	float dist_left = pixel_pos.x;
	float dist_right = viewport_size.x - pixel_pos.x;
	float dist_top = pixel_pos.y;
	float dist_bottom = viewport_size.y - pixel_pos.y;
	
	// Find minimum distance to any edge
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	
	// Calculate exponential fade factor (1.0 at edge, approaches 0 asymptotically)
	// Using exp(-x) which approaches 0 but never reaches it
	float fade_factor = exp(-min_dist / fade_distance);
	
	// Sample the screen texture
	vec4 screen_color = texture(screen_texture, uv);
	
	// Blend with edge color based on fade factor
	COLOR = mix(screen_color, edge_color, fade_factor);
}
