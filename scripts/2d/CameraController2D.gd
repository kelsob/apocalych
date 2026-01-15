extends Camera2D

## Simple 2D Camera Controller
## Pan and zoom controls for viewing the map

@export var zoom_speed: float = 0.1  # Zoom sensitivity
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0
@export var pan_speed: float = 500.0  # Pan speed when using keyboard
@export var enable_mouse_pan: bool = true  # Pan by dragging middle mouse
@export var enable_mouse_zoom: bool = true  # Zoom with scroll wheel

var is_panning: bool = false
var pan_start_position: Vector2 = Vector2.ZERO

func _ready():
	# Center camera at origin
	position = Vector2.ZERO
	zoom = Vector2.ONE

func _input(event):
	# Mouse wheel zoom
	if enable_mouse_zoom and event is InputEventMouseButton:
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
		var current_mouse_pos = get_global_mouse_position()
		var delta = pan_start_position - current_mouse_pos
		position += delta
		pan_start_position = get_global_mouse_position()

func _process(delta):
	# Keyboard panning (WASD or arrow keys)
	var pan_direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		pan_direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		pan_direction.y += 1
	if Input.is_action_pressed("ui_left"):
		pan_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		pan_direction.x += 1
	
	if pan_direction != Vector2.ZERO:
		position += pan_direction.normalized() * pan_speed * delta / zoom.x

func zoom_camera(factor: float):
	var new_zoom = zoom * factor
	new_zoom.x = clamp(new_zoom.x, zoom_min, zoom_max)
	new_zoom.y = clamp(new_zoom.y, zoom_min, zoom_max)
	zoom = new_zoom
