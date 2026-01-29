extends Node2D
class_name StaticMapRenderer

## Renders static map elements to a SubViewport texture for performance optimization
## Receives data from MapGenerator2D and draws static elements once

# ============================================================================
# REFERENCES
# ============================================================================

var map_generator: Control = null  # Reference to parent MapGenerator2D

# ============================================================================
# STATIC ELEMENT DATA
# ============================================================================

var connection_lines_data: Array = []  # Array of dictionaries with line data
var connection_line_highlights_data: Array = []  # Array of highlight/shadow lines for paths
var coastal_water_blobs_data: Array = []  # Array of dictionaries with blob data
var landmass_polygon: PackedVector2Array = PackedVector2Array()  # Landmass polygon points
var landmass_color: Color = Color.WHITE  # Landmass fill color
var biome_blobs_data: Array = []  # Array of biome blob dictionaries
var coast_ripple_lines_data: Array = []  # Array of ripple line dictionaries
var expanded_coast_lines_data: Array = []  # Array of expanded coast line dictionaries
var trees_data: Array = []  # Array of tree dictionaries

# ============================================================================
# CONFIGURATION (inherited from MapGenerator2D)
# ============================================================================

var line_width: float = 2.0
var line_color: Color = Color.WHITE
var use_curved_lines: bool = false

# Coastal water blob configuration
var coastal_water_expansion: float = 35.0
var coastal_water_radius: float = 145.0
var coastal_water_circles: int = 8
var coastal_water_color: Color = Color(0.25, 0.45, 0.7, 1.0)
var coastal_water_alpha_max: float = 0.45

# Biome blob configuration
var biome_blob_radius: float = 55.0
var biome_blob_circles: int = 6
var biome_blob_alpha_max: float = 0.175

# Tree configuration
var tree_foliage_radius: float = 3.5
var tree_foliage_color: Color = Color(0.2, 0.5, 0.2, 1.0)
var tree_foliage_outline_width: float = 0.8
var tree_trunk_width: float = 1.0
var tree_trunk_length: float = 2.5
var tree_trunk_color: Color = Color(0.4, 0.25, 0.15, 1.0)

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
	connection_line_highlights_data.clear()
	coastal_water_blobs_data.clear()
	landmass_polygon.clear()
	biome_blobs_data.clear()
	coast_ripple_lines_data.clear()
	expanded_coast_lines_data.clear()
	trees_data.clear()

# ============================================================================
# DATA RECEPTION - MapGenerator2D calls these to pass data
# ============================================================================

## Add a connection line to be drawn
## line_data should contain: { pos_a: Vector2, pos_b: Vector2, color: Color, width: float, curve_data: Dictionary (optional) }
func add_connection_line(line_data: Dictionary):
	connection_lines_data.append(line_data)

## Add a connection line highlight to be drawn (offset shadow/highlight effect)
## line_data should contain: { pos_a: Vector2, pos_b: Vector2, color: Color, width: float, curve_data: Dictionary (optional) }
func add_connection_line_highlight(line_data: Dictionary):
	connection_line_highlights_data.append(line_data)

## Add a coastal water blob to be drawn
## blob_data should contain: { center: Vector2, node_center: Vector2, away_direction: float }
func add_coastal_water_blob(blob_data: Dictionary):
	coastal_water_blobs_data.append(blob_data)

## Set the landmass polygon to be drawn
func set_landmass_polygon(polygon: PackedVector2Array, color: Color):
	landmass_polygon = polygon
	landmass_color = color

## Add a biome blob to be drawn
## blob_data should contain: { center: Vector2, biome_color: Color }
func add_biome_blob(blob_data: Dictionary):
	biome_blobs_data.append(blob_data)

## Add a coast ripple line to be drawn
## ripple_data should contain: { pos_a: Vector2, pos_b: Vector2, color: Color, width: float }
func add_coast_ripple_line(ripple_data: Dictionary):
	coast_ripple_lines_data.append(ripple_data)

## Add an expanded coast line to be drawn
## coast_line_data should contain: { pos_a: Vector2, pos_b: Vector2, color: Color, width: float }
func add_expanded_coast_line(coast_line_data: Dictionary):
	expanded_coast_lines_data.append(coast_line_data)

## Add a tree to be drawn
## tree_data should contain: { position: Vector2, vertical_stretch: float }
func add_tree(tree_data: Dictionary):
	trees_data.append(tree_data)

## Set configuration from MapGenerator2D
func set_config(config: Dictionary):
	if config.has("line_width"):
		line_width = config["line_width"]
	if config.has("line_color"):
		line_color = config["line_color"]
	if config.has("use_curved_lines"):
		use_curved_lines = config["use_curved_lines"]
	
	# Coastal water blob configuration
	if config.has("coastal_water_expansion"):
		coastal_water_expansion = config["coastal_water_expansion"]
	if config.has("coastal_water_radius"):
		coastal_water_radius = config["coastal_water_radius"]
	if config.has("coastal_water_circles"):
		coastal_water_circles = config["coastal_water_circles"]
	if config.has("coastal_water_color"):
		coastal_water_color = config["coastal_water_color"]
	if config.has("coastal_water_alpha_max"):
		coastal_water_alpha_max = config["coastal_water_alpha_max"]
	
	# Biome blob configuration
	if config.has("biome_blob_radius"):
		biome_blob_radius = config["biome_blob_radius"]
	if config.has("biome_blob_circles"):
		biome_blob_circles = config["biome_blob_circles"]
	if config.has("biome_blob_alpha_max"):
		biome_blob_alpha_max = config["biome_blob_alpha_max"]
	
	# Tree configuration
	if config.has("tree_foliage_radius"):
		tree_foliage_radius = config["tree_foliage_radius"]
	if config.has("tree_foliage_color"):
		tree_foliage_color = config["tree_foliage_color"]
	if config.has("tree_foliage_outline_width"):
		tree_foliage_outline_width = config["tree_foliage_outline_width"]
	if config.has("tree_trunk_width"):
		tree_trunk_width = config["tree_trunk_width"]
	if config.has("tree_trunk_length"):
		tree_trunk_length = config["tree_trunk_length"]
	if config.has("tree_trunk_color"):
		tree_trunk_color = config["tree_trunk_color"]

# ============================================================================
# RENDERING
# ============================================================================

func _draw():
	# Draw in order from bottom to top
	_draw_coastal_water_blobs()  # Bottom layer (water)
	_draw_coast_ripples()  # Ripples in the water
	_draw_landmass_fill()  # Landmass base color
	_draw_expanded_coast_lines()  # Coast border/outline (on top of landmass base)
	_draw_biome_blobs()  # Biome colors on land
	_draw_connection_line_highlights()  # Path highlights/shadows (underneath main paths)
	_draw_connection_lines()  # Paths/roads
	_draw_trees()  # Trees on top of paths

## Draw all coastal water blobs that were added
func _draw_coastal_water_blobs():
	for blob_data in coastal_water_blobs_data:
		var node_center: Vector2 = blob_data.get("node_center", Vector2.ZERO)
		var away_direction: float = blob_data.get("away_direction", 0.0)
		
		# Calculate center position (same logic as MapGenerator2D)
		var away = Vector2(cos(away_direction), sin(away_direction))
		var center = node_center + away * coastal_water_expansion
		var base = coastal_water_color
		
		# Draw concentric circles with gradient from center to edge
		for i in range(coastal_water_circles):
			var t = float(i) / float(coastal_water_circles)
			var r = coastal_water_radius * (1.0 - t)
			var a = base.a * coastal_water_alpha_max * (0.1 + 0.9 * t)
			var col = Color(base.r, base.g, base.b, a)
			draw_circle(center, r, col)

## Draw the landmass fill polygon
func _draw_landmass_fill():
	if landmass_polygon.size() >= 3:
		draw_colored_polygon(landmass_polygon, landmass_color)

## Draw all biome blobs that were added
func _draw_biome_blobs():
	for blob_data in biome_blobs_data:
		var center: Vector2 = blob_data.get("center", Vector2.ZERO)
		var base: Color = blob_data.get("biome_color", Color.WHITE)
		
		# Draw concentric circles with gradient from edge to center (same logic as MapGenerator2D)
		for i in range(biome_blob_circles):
			var t = float(i) / float(biome_blob_circles)
			var r = biome_blob_radius * (1.0 - t)
			var a = biome_blob_alpha_max * (0.1 + 0.9 * t)
			var col = Color(base.r, base.g, base.b, a)
			draw_circle(center, r, col)

## Draw all trees that were added
func _draw_trees():
	# Y-sort trees: trees with lower Y (further up) draw first, higher Y (further down) draw on top
	var sorted_trees = trees_data.duplicate()
	sorted_trees.sort_custom(func(a, b): return a.get("position", Vector2.ZERO).y < b.get("position", Vector2.ZERO).y)
	
	for tree_data in sorted_trees:
		# Extract tree properties (with fallbacks to defaults)
		var position: Vector2 = tree_data.get("position", Vector2.ZERO)
		var vertical_stretch: float = tree_data.get("vertical_stretch", 1.0)
		var foliage_radius: float = tree_data.get("foliage_radius", tree_foliage_radius)
		var foliage_color: Color = tree_data.get("foliage_color", tree_foliage_color)
		var trunk_color: Color = tree_data.get("trunk_color", tree_trunk_color)
		var trunk_width: float = tree_data.get("trunk_width", tree_trunk_width)
		var trunk_length: float = tree_data.get("trunk_length", tree_trunk_length)
		var outline_width: float = tree_data.get("outline_width", tree_foliage_outline_width)
		
		# Calculate foliage dimensions
		var radius_x = foliage_radius
		var radius_y = foliage_radius * vertical_stretch
		
		# Draw trunk (small line extending down from bottom center of foliage)
		var trunk_start = position + Vector2(0, radius_y)
		var trunk_end = trunk_start + Vector2(0, trunk_length)
		draw_line(trunk_start, trunk_end, trunk_color, trunk_width)
		
		# Draw foliage with outline
		# If stretching is needed, we'll approximate with a polygon
		if abs(vertical_stretch - 1.0) < 0.01:
			# No significant stretching, just draw circles
			# Draw outline first (larger circle with trunk color)
			if outline_width > 0:
				draw_circle(position, foliage_radius + outline_width, trunk_color)
			# Draw main foliage on top
			draw_circle(position, foliage_radius, foliage_color)
		else:
			# Draw stretched circle as polygons
			var segments = 24
			
			# Draw outline first (trunk color, slightly larger)
			if outline_width > 0:
				var outline_points: PackedVector2Array = []
				var outline_radius_x = radius_x + outline_width
				var outline_radius_y = radius_y + outline_width
				for i in range(segments):
					var angle = (float(i) / float(segments)) * TAU
					var x = position.x + cos(angle) * outline_radius_x
					var y = position.y + sin(angle) * outline_radius_y
					outline_points.append(Vector2(x, y))
				draw_colored_polygon(outline_points, trunk_color)
			
			# Draw main foliage on top
			var points: PackedVector2Array = []
			for i in range(segments):
				var angle = (float(i) / float(segments)) * TAU
				var x = position.x + cos(angle) * radius_x
				var y = position.y + sin(angle) * radius_y
				points.append(Vector2(x, y))
			draw_colored_polygon(points, foliage_color)

## Draw all connection line highlights (offset lighter lines underneath main paths)
func _draw_connection_line_highlights():
	for line_data in connection_line_highlights_data:
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

## Draw all coast ripple lines that were added
func _draw_coast_ripples():
	for ripple_data in coast_ripple_lines_data:
		var pos_a: Vector2 = ripple_data.get("pos_a", Vector2.ZERO)
		var pos_b: Vector2 = ripple_data.get("pos_b", Vector2.ZERO)
		var color: Color = ripple_data.get("color", Color.WHITE)
		var width: float = ripple_data.get("width", 2.0)
		
		# Draw line
		draw_line(pos_a, pos_b, color, width)
		
		# Draw rounded caps
		var cap_radius = width / 2.0
		draw_circle(pos_a, cap_radius, color)
		draw_circle(pos_b, cap_radius, color)

## Draw all expanded coast lines that were added
func _draw_expanded_coast_lines():
	for coast_line_data in expanded_coast_lines_data:
		var pos_a: Vector2 = coast_line_data.get("pos_a", Vector2.ZERO)
		var pos_b: Vector2 = coast_line_data.get("pos_b", Vector2.ZERO)
		var color: Color = coast_line_data.get("color", Color.WHITE)
		var width: float = coast_line_data.get("width", 3.0)
		
		# Draw line
		draw_line(pos_a, pos_b, color, width)
		
		# Draw rounded caps
		var cap_radius = width / 2.0
		draw_circle(pos_a, cap_radius, color)
		draw_circle(pos_b, cap_radius, color)

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
