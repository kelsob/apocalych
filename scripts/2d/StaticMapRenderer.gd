extends Node2D
class_name StaticMapRenderer

## Renders static map elements to a SubViewport texture for performance optimization
## Receives data from MapGenerator2D and draws static elements once

# ============================================================================
# REFERENCES
# ============================================================================

var map_generator: Control = null  # Reference to parent MapGenerator2D

# ============================================================================
# CONNECTION LINES DATA (Test element)
# ============================================================================

var connection_lines_data: Array = []  # Array of dictionaries with line data

# ============================================================================
# CONFIGURATION (inherited from MapGenerator2D)
# ============================================================================

var line_width: float = 2.0
var line_color: Color = Color.WHITE
var use_curved_lines: bool = false

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	# Get reference to MapGenerator2D (grandparent)
	map_generator = get_parent().get_parent()
	if not map_generator:
		push_error("StaticMapRenderer: Could not find MapGenerator2D parent")

## Clear all stored data (call before regenerating map)
func clear_data():
	connection_lines_data.clear()

# ============================================================================
# DATA RECEPTION - MapGenerator2D calls these to pass data
# ============================================================================

## Add a connection line to be drawn
## line_data should contain: { pos_a: Vector2, pos_b: Vector2, color: Color, width: float, curve_data: Dictionary (optional) }
func add_connection_line(line_data: Dictionary):
	connection_lines_data.append(line_data)

## Set configuration from MapGenerator2D
func set_config(config: Dictionary):
	if config.has("line_width"):
		line_width = config["line_width"]
	if config.has("line_color"):
		line_color = config["line_color"]
	if config.has("use_curved_lines"):
		use_curved_lines = config["use_curved_lines"]

# ============================================================================
# RENDERING
# ============================================================================

func _draw():
	# TEST: Only draw connection lines for now
	_draw_connection_lines()

## Draw all connection lines that were added
func _draw_connection_lines():
	for line_data in connection_lines_data:
		var pos_a: Vector2 = line_data.get("pos_a", Vector2.ZERO)
		var pos_b: Vector2 = line_data.get("pos_b", Vector2.ZERO)
		var color: Color = line_data.get("color", line_color)
		var width: float = line_data.get("width", line_width)
		
		if line_data.has("curve_data") and use_curved_lines:
			# Draw curved line (matches MapGenerator2D curve logic)
			var curve_data = line_data["curve_data"]
			_draw_bezier_curve(pos_a, pos_b, curve_data, color, width)
		else:
			# Draw straight line
			draw_line(pos_a, pos_b, color, width)

## Draw Bezier curve (matches MapGenerator2D curve rendering)
func _draw_bezier_curve(pos_a: Vector2, pos_b: Vector2, curve_data: Dictionary, color: Color, width: float):
	var distance = pos_a.distance_to(pos_b)
	var points: PackedVector2Array = []
	
	if curve_data.get("is_s_curve", false):
		# S-curve: cubic Bezier with two control points
		var control1: Vector2 = curve_data.get("control1", (pos_a + pos_b) / 2.0)
		var control2: Vector2 = curve_data.get("control2", (pos_a + pos_b) / 2.0)
		var segments = max(12, int(distance / 4.0))
		
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			var t2 = t * t
			var t3 = t2 * t
			var mt = 1.0 - t
			var mt2 = mt * mt
			var mt3 = mt2 * mt
			
			# Cubic Bezier: (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
			var point = mt3 * pos_a + 3.0 * mt2 * t * control1 + 3.0 * mt * t2 * control2 + t3 * pos_b
			points.append(point)
	else:
		# Single curve: quadratic Bezier with one control point
		var control: Vector2 = curve_data.get("control_point", (pos_a + pos_b) / 2.0)
		var segments = max(8, int(distance / 5.0))
		
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			var mt = 1.0 - t
			
			# Quadratic Bezier: (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
			var point = mt * mt * pos_a + 2.0 * mt * t * control + t * t * pos_b
			points.append(point)
	
	# Draw polyline
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)
