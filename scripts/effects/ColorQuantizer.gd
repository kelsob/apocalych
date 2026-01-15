extends CanvasLayer

## Post-processing effect that quantizes all colors in the scene to a limited palette
## Attach this script to a CanvasLayer node in your scene

@export_group("Color Quantization")
@export_range(2, 16, 1) var color_levels: int = 4:
	set(value):
		color_levels = value
		_update_shader_params()

@export var enable_dithering: bool = false:
	set(value):
		enable_dithering = value
		_update_shader_params()

@export_range(0.0, 1.0) var dither_strength: float = 0.2:
	set(value):
		dither_strength = value
		_update_shader_params()

var color_rect: ColorRect
var shader_material: ShaderMaterial

func _ready() -> void:
	# Create a fullscreen ColorRect to apply the post-process shader
	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Load and apply the quantization shader
	var shader = load("res://color_quantize.gdshader")
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		color_rect.material = shader_material
		
		# Set initial shader parameters
		_update_shader_params()
	else:
		push_error("ColorQuantizer: Could not load color_quantize.gdshader")
	
	add_child(color_rect)
	
	print("ColorQuantizer: Post-process effect enabled with %d color levels (%d total colors)" % [color_levels, color_levels * color_levels * color_levels])

func _update_shader_params() -> void:
	if shader_material:
		shader_material.set_shader_parameter("color_levels", color_levels)
		shader_material.set_shader_parameter("enable_dithering", enable_dithering)
		shader_material.set_shader_parameter("dither_strength", dither_strength)

## Call this to enable/disable the effect at runtime
func set_enabled(enabled: bool) -> void:
	visible = enabled
