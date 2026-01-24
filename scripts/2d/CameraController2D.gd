extends Camera2D

## Simple 2D Camera Controller
## Pan and zoom controls for viewing the map

@export var zoom_speed: float = 0.1  # Zoom sensitivity
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0
@export var pan_speed: float = 500.0  # Pan speed when using keyboard
@export var edge_scroll_speed: float = 800.0  # Pan speed for edge scrolling
@export var edge_scroll_margin: float = 50.0  # Distance from edge to trigger scrolling
@export var enable_mouse_pan: bool = true  # Pan by dragging middle mouse
@export var enable_mouse_zoom: bool = true  # Zoom with scroll wheel
@export var enable_edge_scroll: bool = true  # Pan when mouse is near screen edges

var is_panning: bool = false
var pan_start_position: Vector2 = Vector2.ZERO
var original_map_size: Vector2 = Vector2.ZERO  # Store original map size for zoom-based limit calculations

func _ready():
	# Camera will be centered after map generation
	zoom = Vector2.ONE
	# Limits will be set dynamically after map generation

func _input(event):
	# Mouse wheel zoom - skip if any node is hovered
	var should_skip_zoom = false
	var parent = get_parent()
	if parent and "hovered_node" in parent:
		# Check if parent MapGenerator2D has any hovered node
		if parent.hovered_node != null:
			should_skip_zoom = true
	
	# Mouse wheel zoom - only if no node is hovered
	if enable_mouse_zoom and not should_skip_zoom and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_camera(1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_camera(1.0 - zoom_speed)
	
	# Middle mouse button pan
	if enable_mouse_pan and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				pan_start_position = get_global_mouse_position()
			else:
				is_panning = false
	
	# Mouse motion during pan
	if enable_mouse_pan and is_panning and event is InputEventMouseMotion:
		# If fully zoomed out, ignore panning
		if zoom.x == 1.0 and zoom.y == 1.0:
			return
		
		# Calculate center position (half of map size)
		var center_pos = original_map_size / 2.0
		
		# Calculate viewport-based movement bounds
		var full_viewport_size = original_map_size
		var current_viewport_size = full_viewport_size / zoom
		var max_movement = full_viewport_size - current_viewport_size
		
		# Movement bounds grow out from center position
		var min_pos = center_pos - max_movement / 2.0
		var max_pos = center_pos + max_movement / 2.0
		
		var current_mouse_pos = get_global_mouse_position()
		var delta = pan_start_position - current_mouse_pos
		var old_position = position
		var new_position = position + delta
		
		# Custom clamp based on viewport size calculation
		new_position.x = clamp(new_position.x, min_pos.x, max_pos.x)
		new_position.y = clamp(new_position.y, min_pos.y, max_pos.y)
		
		position = new_position
		pan_start_position = get_global_mouse_position()
		
		if old_position != new_position:
			print("camera: mouse pan position changed from %s to %s (delta=%s)" % [old_position, new_position, delta])

func _process(delta):
	# Calculate center position (half of map size)
	var center_pos = original_map_size / 2.0
	
	# If fully zoomed out, force position to center and ignore all movement
	if zoom.x == 1.0 and zoom.y == 1.0:
		if position != center_pos:
			position = center_pos
		return
	
	# Calculate viewport-based movement bounds
	var full_viewport_size = original_map_size
	var current_viewport_size = full_viewport_size / zoom
	var max_movement = full_viewport_size - current_viewport_size
	
	# Movement bounds grow out from center position
	var min_pos = center_pos - max_movement / 2.0
	var max_pos = center_pos + max_movement / 2.0
	
	var pan_direction = Vector2.ZERO
	var using_keyboard = false
	
	# Keyboard panning (WASD or arrow keys)
	if Input.is_action_pressed("ui_up"):
		pan_direction.y -= 1
		using_keyboard = true
	if Input.is_action_pressed("ui_down"):
		pan_direction.y += 1
		using_keyboard = true
	if Input.is_action_pressed("ui_left"):
		pan_direction.x -= 1
		using_keyboard = true
	if Input.is_action_pressed("ui_right"):
		pan_direction.x += 1
		using_keyboard = true
	
	# Edge scrolling (only if not panning with middle mouse and not using keyboard)
	if enable_edge_scroll and not is_panning and not using_keyboard:
		var viewport = get_viewport()
		if viewport:
			var viewport_mouse = viewport.get_mouse_position()
			var viewport_size = viewport.get_visible_rect().size
			
			# Check edges and add to pan direction
			if viewport_mouse.x < edge_scroll_margin:
				pan_direction.x -= 1
			elif viewport_mouse.x > viewport_size.x - edge_scroll_margin:
				pan_direction.x += 1
			
			if viewport_mouse.y < edge_scroll_margin:
				pan_direction.y -= 1
			elif viewport_mouse.y > viewport_size.y - edge_scroll_margin:
				pan_direction.y += 1
	
	if pan_direction != Vector2.ZERO:
		# Use edge scroll speed for edge scrolling, keyboard speed for keyboard
		var speed = edge_scroll_speed if enable_edge_scroll and not using_keyboard else pan_speed
		var movement = pan_direction.normalized() * speed * delta / zoom.x
		var old_position = position
		var new_position = position + movement
		
		# Custom clamp based on viewport size calculation
		new_position.x = clamp(new_position.x, min_pos.x, max_pos.x)
		new_position.y = clamp(new_position.y, min_pos.y, max_pos.y)
		
		position = new_position
		
		if old_position != new_position:
			print("camera: position changed from %s to %s (pan_direction=%s)" % [old_position, new_position, pan_direction])

func zoom_camera(factor: float):
	var old_zoom = zoom
	var new_zoom = zoom * factor
	# Clamp both X and Y components strictly to min/max bounds
	new_zoom.x = clamp(new_zoom.x, zoom_min, zoom_max)
	new_zoom.y = clamp(new_zoom.y, zoom_min, zoom_max)
	
	# Ensure zoom stays within bounds - no exceptions
	if new_zoom.x < zoom_min:
		new_zoom.x = zoom_min
	if new_zoom.x > zoom_max:
		new_zoom.x = zoom_max
	if new_zoom.y < zoom_min:
		new_zoom.y = zoom_min
	if new_zoom.y > zoom_max:
		new_zoom.y = zoom_max
	
	zoom = new_zoom
	
	# Calculate center position (half of map size)
	var center_pos = original_map_size / 2.0
	
	# If fully zoomed out, force position to center
	if zoom.x == 1.0 and zoom.y == 1.0:
		position = center_pos
	else:
		# Clamp position to new zoom-based bounds (growing out from center)
		var full_viewport_size = original_map_size
		var current_viewport_size = full_viewport_size / zoom
		var max_movement = full_viewport_size - current_viewport_size
		var min_pos = center_pos - max_movement / 2.0
		var max_pos = center_pos + max_movement / 2.0
		position.x = clamp(position.x, min_pos.x, max_pos.x)
		position.y = clamp(position.y, min_pos.y, max_pos.y)
	
	print("camera: zoom changed from %s to %s (factor=%.2f, clamped to [%.2f, %.2f])" % [old_zoom, zoom, factor, zoom_min, zoom_max])
	print("camera: current position=%s" % position)

## Set camera limits based on map control size
## map_size should be the size of the MapGenerator Control in pixels
func set_map_limits(map_size: Vector2):
	print("camera: set_map_limits called with map_size=%s" % map_size)
	
	if map_size == Vector2.ZERO:
		print("camera: ERROR - map_size is ZERO, returning early")
		return
	
	# Store original map size for zoom-based calculations
	original_map_size = map_size
	
	# Disable limit smoothing to prevent drift
	limit_smoothed = false
	
	# Calculate center position (half of map size)
	var center_pos = original_map_size / 2.0
	
	# If fully zoomed out, force position to center
	if zoom.x == 1.0 and zoom.y == 1.0:
		position = center_pos
	else:
		# Clamp position to zoom-based bounds (growing out from center)
		var full_viewport_size = original_map_size
		var current_viewport_size = full_viewport_size / zoom
		var max_movement = full_viewport_size - current_viewport_size
		var min_pos = center_pos - max_movement / 2.0
		var max_pos = center_pos + max_movement / 2.0
		position.x = clamp(position.x, min_pos.x, max_pos.x)
		position.y = clamp(position.y, min_pos.y, max_pos.y)
	
	print("camera: original_map_size=%s, zoom=%s, position=%s" % [original_map_size, zoom, position])
