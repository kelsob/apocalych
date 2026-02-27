extends Node2D

## Draws rivers and lakes on top of trees.
## MapGenerator passes water data via set_water_data() during bake.

var _river_segments: Array = []
var _coastal_blobs: Array = []
var _coast_ripples: Array = []
var _config: Dictionary = {}

func _ready() -> void:
	z_index = 1  # Above Trees (z_index = 0)

func set_water_data(river_segments: Array, coastal_blobs: Array, coast_ripples: Array, config: Dictionary) -> void:
	_river_segments = river_segments
	_coastal_blobs = coastal_blobs
	_coast_ripples = coast_ripples
	_config = config
	queue_redraw()

func _draw() -> void:
	_draw_coastal_water_blobs()
	_draw_coast_ripples()
	_draw_rivers()

func _draw_coastal_water_blobs() -> void:
	var expansion: float = _config.get("coastal_water_expansion", 35.0)
	var radius: float = _config.get("coastal_water_radius", 145.0)
	var circles: int = _config.get("coastal_water_circles", 8)
	var base_color: Color = _config.get("coastal_water_color", Color(0.25, 0.45, 0.7, 1.0))
	var alpha_max: float = _config.get("coastal_water_alpha_max", 0.45)
	for blob_data in _coastal_blobs:
		var node_center: Vector2 = blob_data.get("node_center", Vector2.ZERO)
		var away_direction: float = blob_data.get("away_direction", 0.0)
		var away := Vector2(cos(away_direction), sin(away_direction))
		var center := node_center + away * expansion
		for i in range(circles):
			var t := float(i) / float(circles)
			var r := radius * (1.0 - t)
			var a := base_color.a * alpha_max * (0.1 + 0.9 * t)
			var col := Color(base_color.r, base_color.g, base_color.b, a)
			draw_circle(center, r, col)

func _draw_coast_ripples() -> void:
	for ripple_data in _coast_ripples:
		var pos_a: Vector2 = ripple_data.get("pos_a", Vector2.ZERO)
		var pos_b: Vector2 = ripple_data.get("pos_b", Vector2.ZERO)
		var color: Color = ripple_data.get("color", Color.WHITE)
		var width: float = ripple_data.get("width", 2.0)
		draw_line(pos_a, pos_b, color, width)
		var cap_r := width / 2.0
		draw_circle(pos_a, cap_r, color)
		draw_circle(pos_b, cap_r, color)

func _draw_rivers() -> void:
	for seg in _river_segments:
		var pos_a: Vector2 = seg.get("pos_a", Vector2.ZERO)
		var pos_b: Vector2 = seg.get("pos_b", Vector2.ZERO)
		var width: float = seg.get("width", 2.0)
		var color: Color = seg.get("color", Color(0.3, 0.5, 0.8, 1.0))
		draw_line(pos_a, pos_b, color, width)
		var cap_r := width / 2.0
		draw_circle(pos_a, cap_r, color)
		draw_circle(pos_b, cap_r, color)
