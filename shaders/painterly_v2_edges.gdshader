shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Edge darkening - finds edges and subtly darkens them for ink/charcoal look
uniform float edge_strength : hint_range(0.0, 1.0) = 0.3;
uniform float edge_threshold : hint_range(0.0, 0.5) = 0.05;
uniform vec3 edge_tint : source_color = vec3(0.2, 0.15, 0.1); // Warm dark brown

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	vec4 tex = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Sobel edge detection
	float tl = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-1.0, -1.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float t  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 0.0, -1.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float tr = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 1.0, -1.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float l  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-1.0,  0.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float r  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 1.0,  0.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float bl = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-1.0,  1.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float b  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 0.0,  1.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	float br = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 1.0,  1.0) * pixel_size).rgb, vec3(0.299, 0.587, 0.114));
	
	float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
	float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
	float edge = sqrt(gx*gx + gy*gy);
	
	// Smooth threshold
	float edge_factor = smoothstep(edge_threshold, edge_threshold + 0.1, edge) * edge_strength;
	
	// Darken edges with warm tint
	vec3 result = mix(tex.rgb, edge_tint, edge_factor);
	
	COLOR = vec4(result, tex.a);
}
