extends Control
class_name MapGenerator2D

## Simplified 2D Map Generator
## Features: Poisson-disk sampling, Delaunay triangulation, coastal identification, POI detection, AStar2D

# ============================================================================
# EXPORTS
# ============================================================================

@export var node_count: int = 20
@export var map_size: Vector2 = Vector2(100, 100)  # Ellipse semi-axes
@export var node_scene: PackedScene  # Scene to instantiate for each node

@export_group("Node Placement")
@export var poisson_min_distance: float = 8.0  # Minimum spacing between nodes
@export var poisson_max_attempts: int = 30  # Attempts per sample
@export var poisson_spacing_randomness: float = 0.2  # Random variation in spacing (0.0 = strict, 0.2 = ±20% variation)

@export_group("Shape Variation")
@export var shape_noise_enabled: bool = true
@export var shape_noise_min: float = 0.9
@export var shape_noise_max: float = 1.6
@export var shape_noise_chance_off: float = 0.05

@export_group("Shape Noise Detail")
@export var large_scale_frequency_min: float = 0.2
@export var large_scale_frequency_max: float = 2.0
@export var large_scale_weight_min: float = 0.4
@export var large_scale_weight_max: float = 0.95
@export var small_scale_frequency_min: float = 3.0
@export var small_scale_frequency_max: float = 8.0
@export var small_scale_weight_min: float = 0.05
@export var small_scale_weight_max: float = 0.6

@export_group("Orientation")
@export var enable_rotation: bool = true  # Rotate map so furthest nodes are horizontal

@export_group("Connections")
@export var enable_distance_filtering: bool = true  # Enable by default to prevent long connections
@export var max_connection_distance_multiplier: float = 2.5
@export var min_angle_threshold_degrees: float = 10.0  # Minimum angle (in degrees) to allow a connection

@export_group("Visuals")
@export var line_width: float = 4.0
@export var line_color: Color = Color(0.588, 0.482, 0.298)  # #967b4c - Node connections
@export var node_base_color: Color = Color(0.635, 0.518, 0.349)  # #a28459 - Node color
@export var coast_line_color: Color = Color(0.600, 0.376, 0.192)  # #996031 - Coast lines
@export var coast_expansion_distance: float = 20.0  # How far to expand coast outward from edges
@export var coast_line_width: float = 3.0  # Width of the coast line
@export var horizontal_line_width_multiplier: float = 1.5  # How much thicker horizontal lines are (1.0 = no change, 1.5 = 50% thicker)
@export var horizontal_line_darken: float = 0.08  # How much darker horizontal lines are (0.0-1.0, subtle amount)
@export var coastal_neighbor_weight_when_mixed: float = 0.5  # Weight for coastal neighbors when non-coastal neighbors also exist (0.0-1.0)
@export var trail_color: Color = Color(0.709, 0.0, 0.0, 1.0)  # #b50000 - Player trail color
@export var trail_line_width: float = 3.0  # Width of the trail line
@export var trail_dot_length: float = 4.0  # Length of each dot segment
@export var trail_dot_gap: float = 3.0  # Gap between dot segments
@export var trail_dot_size_variation: float = 0.15  # ±15% size variation for dots
@export var trail_dot_spacing_variation: float = 0.2  # ±20% spacing variation for gaps
@export var trail_outline_width: float = 1.0  # Width of outline around dots
@export var trail_outline_color: Color = Color(0.4, 0.0, 0.0, 1.0)  # Darker red for outline

@export_group("Hover Preview")
@export var preview_path_color: Color = Color(1.0, 0.9, 0.3, 0.6)  # Glowy yellow, low opacity
@export var preview_path_dot_size: float = 5.0  # Bigger dots for preview
@export var preview_path_dot_gap: float = 4.0  # Gap between preview dots
@export var enable_pass1: bool = true  # Process all nodes with 3+ connections
@export var enable_pass2: bool = true  # Process nodes with exactly 2 connections
@export var use_curved_lines: bool = true  # Use smooth curves instead of straight lines

# Landmass shading
@export var enable_landmass_shading: bool = true  # Fill the landmass with color
@export var landmass_base_color: Color = Color(0.757, 0.635, 0.467, 1.0)  # #c1a277 - Landmass color
@export var landmass_coast_darken: float = 0.3  # How much darker at coast (0.0-1.0)
@export var landmass_gradient_distance: float = 100.0  # Distance from coast where gradient fades
@export var curve_strength: float = 0.3  # How much curves bend (0.0 = straight, 0.5 = strong curves)
@export var s_curve_threshold: float = 50.0  # Distance above which S-curves become more likely
@export var s_curve_probability: float = 0.6  # Probability of S-curve for long paths

# Coastal ripples (concentric lines expanding from coast)
@export var enable_coast_ripples: bool = true
@export var ripple_count: int = 3  # Number of ripple lines
@export var ripple_base_spacing: float = 12.0  # Distance between ripples
@export var ripple_spacing_growth: float = 1.2  # Each ripple is this much further than the last (multiplier)
@export var ripple_base_width: float = 2.0  # Width of first ripple
@export var ripple_width_decay: float = 0.7  # Each ripple is this fraction of previous width
@export var ripple_base_color: Color = Color(0.55, 0.45, 0.32, 0.8)  # Starting ripple color
@export var ripple_color_fade: float = 0.25  # How much lighter each successive ripple gets (added to RGB)
@export var ripple_alpha_decay: float = 0.7  # Each ripple is this fraction of previous alpha

@export_group("Regions")
@export var region_count: int = 6

@export_group("Mountains")
@export var enable_mountains: bool = true

@export_group("Error Handling")
@export var auto_regenerate_on_error: bool = true

@export_group("Party")
@export var party_travel_speed: float = 200.0  # Pixels per second
@export var party_wait_at_node: float = 0.3  # Seconds to wait at a node before accepting new input

# Map state machine
enum MapState {
	IDLE,           # Default state - waiting for input
	PARTY_MOVING    # Party is traveling along a path
}

var map_state: MapState = MapState.IDLE
var events_paused: bool = false  # True when event window is open, prevents all map interaction

# Party state
var current_party_node: MapNode2D = null

# Hover preview state
var hovered_node: MapNode2D = null
var hover_preview_path: PackedVector2Array = PackedVector2Array()
var hover_alternative_paths: Array[Array] = []  # Array of Arrays of node indices (each path)
var hover_current_path_index: int = 0  # Which alternative path we're currently showing

# Party travel state (only valid when map_state == PARTY_MOVING)
var travel_path_points: PackedVector2Array = PackedVector2Array()
var travel_target_node: MapNode2D = null
var travel_total_distance: float = 0.0
var travel_elapsed_distance: float = 0.0
var travel_wait_timer: float = 0.0
var travel_start_node: MapNode2D = null  # Starting node for current travel
var travel_current_path: PackedVector2Array = PackedVector2Array()  # Current path being drawn in real-time

# Player trail tracking
var visited_paths: Dictionary = {}  # "node1_node2" -> PackedVector2Array (completed path points)
var current_travel_path: PackedVector2Array = PackedVector2Array()  # Path currently being drawn (in progress)

# Party indicator node (user will instantiate and assign via @onready)
@onready var party_indicator: Sprite2D = $PartyIndicator
@onready var mapnodes: Control = $MapNodes
@onready var world_name_label: Label = $MapDetails/Control/WorldNameLabel
@onready var game_camera: Camera2D = $GameCamera
# ============================================================================
# SIGNALS
# ============================================================================

signal map_generation_complete

# ============================================================================
# INTERNAL VARIABLES
# ============================================================================

var _regeneration_requested: bool = false

var map_nodes: Array[MapNode2D] = []
var node_positions: Array[Vector2] = []
var coastal_nodes: Array[MapNode2D] = []
var coastal_connections: Array = []  # Stored pairs [node_a, node_b] for coastal edges
var expanded_coast_lines: Array = []  # Array of [pos_a, pos_b] for expanded coast lines
var astar: AStar2D

# Shape noise
var shape_noise_large: FastNoiseLite
var shape_noise_small: FastNoiseLite
var current_noise_intensity: float = 0.0
var current_large_scale_weight: float = 0.0
var current_small_scale_weight: float = 0.0

# Delaunay triangulation
var delaunay_edges: Array = []  # Array of [Vector2, Vector2] edges
# ============================================================================
# CORE GENERATION
# ============================================================================

func _ready():
	# Set to fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ensure we draw on top of backgrounds
	z_index = 1
	# Map generation will be triggered manually when game starts

## Set the world name and update the label
func set_world_name(name: String):
	if world_name_label:
		world_name_label.text = name


func generate_map():
	print("=== Starting 2D Map Generation ===")
	
	# Step 1: Clear existing
	print("Step 1: Clearing existing nodes...")
	clear_existing_nodes()
	
	# Step 2: Initialize shape noise
	print("Step 2: Initializing shape noise...")
	initialize_shape_noise()
	
	# Step 3: Generate positions (Poisson-disk sampling)
	print("Step 3: Generating node positions...")
	generate_poisson_positions()
	
	# Step 4: Instantiate nodes
	print("Step 4: Instantiating nodes...")
	instantiate_nodes()
	
	# Step 5: Wait for nodes to be added
	await get_tree().process_frame
	
	# Step 6: Center at origin
	print("Step 6: Centering points at origin...")
	center_points_at_origin()
	
	# Step 6.5: Rotate to horizontal (after centering, before connections)
	if enable_rotation:
		print("Step 6.5: Rotating to horizontal...")
		rotate_to_horizontal()
		
		# Step 6.6: Vertically center after rotation
		print("Step 6.6: Vertically centering nodes...")
		vertically_center_nodes()
	
	# Step 7: Generate connections (Delaunay)
	print("Step 7: Generating connections (Delaunay)...")
	generate_delaunay_connections()
	
	# Step 8: Filter edges by distance (optional)
	if enable_distance_filtering:
		print("Step 8: Filtering edges by distance...")
		filter_edges_by_distance()
	
	# Step 8.25: Filter edges by minimum angle (prevent very small angles)
	print("Step 8.25: Filtering edges by minimum angle...")
	filter_edges_by_angle()
	
	# Step 8.5: Validate nodes and connections (check for duplicates/overlaps)
	print("Step 8.5: Validating nodes and connections...")
	validate_nodes()
	
	# Step 9: Identify coastal nodes (BEFORE mountains, so connections are intact)
	print("Step 9: Identifying coastal nodes...")
	identify_coastal_nodes()
	
	# Step 10: Build AStar2D graph
	print("Step 10: Building AStar2D pathfinding graph...")
	build_astar_graph()
	
	# Step 11: Identify points of interest
	print("Step 11: Identifying points of interest...")
	identify_points_of_interest()
	
	# Step 12: Create regions
	print("Step 12: Creating regions...")
	create_regions()
	
	# Step 12.5: Generate mountains at region boundaries
	if enable_mountains:
		print("Step 12.5: Generating mountains at region boundaries...")
		generate_mountains_at_borders()
		
		# Step 12.55: Center mountain nodes at average position of connected nodes
		print("Step 12.55: Centering mountain nodes...")
		center_mountain_nodes()
		
		# Step 12.6: Disconnect mountain nodes (mountains act as barriers)
		print("Step 12.6: Disconnecting mountain nodes...")
		disconnect_mountain_nodes()
	
	# Step 13: Visualize
	print("Step 13: Visualizing map...")
	visualize_map()
	
	# Check if regeneration was requested due to errors
	if _regeneration_requested:
		_regeneration_requested = false
		print("=== Regenerating map due to detected errors ===")
		regenerate_map()
		return
	
	print("=== 2D Map Generation Complete ===")
	
	# Enable camera when game starts and set its limits based on control size
	if game_camera:
		print("camera: MapGenerator Control size=%s, global_position=%s" % [size, global_position])
		game_camera.enabled = true
		# Wait a frame for Control size to be properly set, then set camera limits
		await get_tree().process_frame
		print("camera: After frame wait, MapGenerator Control size=%s" % size)
		game_camera.set_map_limits(size)
	else:
		print("camera: ERROR - game_camera is null!")
	
	# Emit signal that generation is complete
	map_generation_complete.emit()
	
	# Spawn party after map generation is fully complete
	spawn_party()

# ============================================================================
# STEP 1: CLEAR EXISTING
# ============================================================================

func clear_existing_nodes():
	for node in map_nodes:
		if is_instance_valid(node):
			node.queue_free()
	map_nodes.clear()
	node_positions.clear()
	coastal_nodes.clear()
	coastal_connections.clear()
	expanded_coast_lines.clear()
	delaunay_edges.clear()
	visited_paths.clear()
	current_travel_path.clear()
	if is_inside_tree():
		queue_redraw()  # Clear drawn lines

# ============================================================================
# STEP 2: INITIALIZE SHAPE NOISE
# ============================================================================

func initialize_shape_noise():
	# Determine noise intensity
	if randf() < shape_noise_chance_off or not shape_noise_enabled:
		current_noise_intensity = 0.0
		print("  Shape noise: DISABLED (pure ellipse)")
		return
	
	current_noise_intensity = randf_range(shape_noise_min, shape_noise_max)
	
	# Create large-scale noise
	shape_noise_large = FastNoiseLite.new()
	shape_noise_large.noise_type = FastNoiseLite.TYPE_SIMPLEX
	shape_noise_large.seed = randi()
	shape_noise_large.frequency = randf_range(large_scale_frequency_min, large_scale_frequency_max)
	current_large_scale_weight = randf_range(large_scale_weight_min, large_scale_weight_max)
	
	# Create small-scale noise
	shape_noise_small = FastNoiseLite.new()
	shape_noise_small.noise_type = FastNoiseLite.TYPE_SIMPLEX
	shape_noise_small.seed = randi()
	shape_noise_small.frequency = randf_range(small_scale_frequency_min, small_scale_frequency_max)
	current_small_scale_weight = randf_range(small_scale_weight_min, small_scale_weight_max)
	
	print("  Noise intensity: %.2f" % current_noise_intensity)

# ============================================================================
# STEP 3: POISSON-DISK SAMPLING
# ============================================================================

func generate_poisson_positions():
	node_positions.clear()
	
	var a = map_size.x / 2.0  # Semi-major axis
	var b = map_size.y / 2.0  # Semi-minor axis
	
	var cell_size = poisson_min_distance / sqrt(2.0)
	var grid_width = ceil((map_size.x * 1.8) / cell_size)
	var grid_height = ceil((map_size.y * 1.8) / cell_size)
	
	# Spatial grid for fast lookup
	var grid = []
	for i in range(grid_width * grid_height):
		grid.append(-1)
	
	var active_list: Array[Vector2] = []
	
	# Start with random point
	var initial_point = get_random_point_in_ellipse(a, b)
	node_positions.append(initial_point)
	active_list.append(initial_point)
	var grid_idx = get_grid_index(initial_point, cell_size, grid_width, a, b)
	if grid_idx >= 0 and grid_idx < grid.size():
		grid[grid_idx] = 0
	
	# Main sampling loop
	while active_list.size() > 0 and node_positions.size() < node_count:
		var random_idx = randi() % active_list.size()
		var point = active_list[random_idx]
		var found_valid = false
		
		for attempt in range(poisson_max_attempts):
			# Add randomness to the distance range
			var min_dist = poisson_min_distance * (1.0 - poisson_spacing_randomness * 0.5)
			var max_dist = 2.0 * poisson_min_distance * (1.0 + poisson_spacing_randomness * 0.5)
			var new_point = generate_point_around(point, min_dist, max_dist)
			
			if not is_point_in_ellipse(new_point, a, b):
				continue
			
			if is_valid_poisson_point(new_point, cell_size, grid, grid_width, grid_height, a, b):
				node_positions.append(new_point)
				active_list.append(new_point)
				var new_grid_idx = get_grid_index(new_point, cell_size, grid_width, a, b)
				if new_grid_idx >= 0 and new_grid_idx < grid.size():
					grid[new_grid_idx] = node_positions.size() - 1
				found_valid = true
				
				if node_positions.size() >= node_count:
					break
		
		if not found_valid:
			active_list.remove_at(random_idx)
	
	print("  Generated %d nodes" % node_positions.size())

func get_random_point_in_ellipse(a: float, b: float) -> Vector2:
	var angle = randf() * TAU
	var r = sqrt(randf())
	
	var radius_multiplier = 1.0
	if current_noise_intensity > 0.0 and shape_noise_large != null and shape_noise_small != null:
		var large_noise = shape_noise_large.get_noise_2d(cos(angle) * 10.0, sin(angle) * 10.0)
		var small_noise = shape_noise_small.get_noise_2d(cos(angle) * 10.0, sin(angle) * 10.0)
		var combined_noise = (large_noise * current_large_scale_weight) + (small_noise * current_small_scale_weight)
		radius_multiplier = 1.0 + (combined_noise * current_noise_intensity)
		radius_multiplier = clamp(radius_multiplier, 0.3, 1.7)
	
	var x = a * r * cos(angle) * radius_multiplier
	var y = b * r * sin(angle) * radius_multiplier
	return Vector2(x, y)

func generate_point_around(center: Vector2, min_dist: float, max_dist: float) -> Vector2:
	var angle = randf() * TAU
	var radius = min_dist + randf() * (max_dist - min_dist)
	return Vector2(
		center.x + radius * cos(angle),
		center.y + radius * sin(angle)
	)

func is_point_in_ellipse(point: Vector2, a: float, b: float) -> bool:
	var distance = (point.x * point.x) / (a * a) + (point.y * point.y) / (b * b)
	
	var max_radius = 1.0
	if current_noise_intensity > 0.0 and shape_noise_large != null and shape_noise_small != null:
		var angle = atan2(point.y, point.x)
		var large_noise = shape_noise_large.get_noise_2d(cos(angle) * 10.0, sin(angle) * 10.0)
		var small_noise = shape_noise_small.get_noise_2d(cos(angle) * 10.0, sin(angle) * 10.0)
		var combined_noise = (large_noise * current_large_scale_weight) + (small_noise * current_small_scale_weight)
		var radius_multiplier = 1.0 + (combined_noise * current_noise_intensity)
		radius_multiplier = clamp(radius_multiplier, 0.3, 1.7)
		max_radius *= radius_multiplier
	
	return distance <= max_radius

func get_grid_index(point: Vector2, cell_size: float, grid_width: int, a: float, b: float) -> int:
	var x = int((point.x + a) / cell_size)
	var y = int((point.y + b) / cell_size)
	
	if x < 0 or y < 0:
		return -1
	
	var grid_height = ceil((b * 2.0 * 1.8) / cell_size)
	if x >= grid_width or y >= grid_height:
		return -1
	
	return y * grid_width + x

func is_valid_poisson_point(point: Vector2, cell_size: float, grid: Array, grid_width: int, grid_height: int, a: float, b: float) -> bool:
	var grid_x = int((point.x + a) / cell_size)
	var grid_y = int((point.y + b) / cell_size)
	
	var search_radius = 2
	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var nx = grid_x + dx
			var ny = grid_y + dy
			
			if nx < 0 or ny < 0 or nx >= grid_width or ny >= grid_height:
				continue
			
			var neighbor_idx = ny * grid_width + nx
			if neighbor_idx < 0 or neighbor_idx >= grid.size():
				continue
			
			var stored_idx = grid[neighbor_idx]
			if stored_idx >= 0 and stored_idx < node_positions.size():
				var neighbor = node_positions[stored_idx]
				# Add randomness to spacing check
				var required_distance = poisson_min_distance * (1.0 - randf_range(-poisson_spacing_randomness, poisson_spacing_randomness))
				if point.distance_to(neighbor) < required_distance:
					return false
	
	return true

# ============================================================================
# STEP 4: INSTANTIATE NODES
# ============================================================================

func instantiate_nodes():
	for i in range(node_positions.size()):
		var pos = node_positions[i]
		var node_instance = node_scene.instantiate() as MapNode2D
		
		if node_instance == null:
			push_error("node_scene must be a MapNode2D scene! Current scene is not compatible with 2D generation.")
			return
		
		node_instance.node_index = i
		mapnodes.add_child(node_instance)
		
		# Connect node click signal for debugging (button press -> signal -> handler)
		node_instance.node_clicked.connect(_on_node_clicked)
		node_instance.node_hovered.connect(_on_node_hovered)
		node_instance.node_hover_ended.connect(_on_node_hover_ended)
		
		# Defer positioning to ensure Control is in tree
		call_deferred("defer_node_setup", node_instance, pos)
		map_nodes.append(node_instance)
	
	print("  Instantiated %d nodes" % map_nodes.size())

func validate_nodes():
	# Check for overlapping/duplicate nodes
	var overlap_threshold = 1.0  # Nodes closer than this are considered overlapping
	var overlapping_pairs: Array = []
	
	for i in range(map_nodes.size()):
		var node_a = map_nodes[i]
		var pos_a = node_a.position + (node_a.size / 2.0)
		
		for j in range(i + 1, map_nodes.size()):
			var node_b = map_nodes[j]
			var pos_b = node_b.position + (node_b.size / 2.0)
			
			var distance = pos_a.distance_to(pos_b)
			if distance < overlap_threshold:
				overlapping_pairs.append([node_a.node_index, node_b.node_index, distance])
	
	if overlapping_pairs.size() > 0:
		print("  WARNING: Found %d overlapping node pairs:" % overlapping_pairs.size())
		for pair in overlapping_pairs:
			print("    Nodes %d and %d are %.2f units apart" % [pair[0], pair[1], pair[2]])
	
	# Check for duplicate connections in node connection lists
	var duplicate_connections = 0
	for node in map_nodes:
		var seen_neighbors: Dictionary = {}
		for neighbor in node.connections:
			if seen_neighbors.has(neighbor.node_index):
				duplicate_connections += 1
				print("  WARNING: Node %d has duplicate connection to node %d" % [node.node_index, neighbor.node_index])
			else:
				seen_neighbors[neighbor.node_index] = true
		
		# Also check if node is connected to itself
		if seen_neighbors.has(node.node_index):
			print("  ERROR: Node %d is connected to itself!" % node.node_index)
	
	if duplicate_connections > 0:
		print("  WARNING: Found %d duplicate connections" % duplicate_connections)
	
	# Check for asymmetric connections (A has B but B doesn't have A)
	var asymmetric_connections = 0
	for node in map_nodes:
		for neighbor in node.connections:
			if node not in neighbor.connections:
				asymmetric_connections += 1
				print("  ERROR: Asymmetric connection: Node %d has %d, but %d doesn't have %d" % [node.node_index, neighbor.node_index, neighbor.node_index, node.node_index])
	
	if asymmetric_connections > 0:
		print("  ERROR: Found %d asymmetric connections" % asymmetric_connections)
	else:
		print("  Node validation passed (no overlaps, duplicates, or asymmetric connections)")

func defer_node_setup(node: MapNode2D, pos: Vector2):
	# Control nodes position from top-left, so offset by half size to center
	node.position = pos - (node.size / 2.0)

# ============================================================================
# STEP 6: CENTER AT ORIGIN
# ============================================================================

func center_points_at_origin():
	if map_nodes.size() == 0:
		return
	
	# Calculate center of all nodes (accounting for Control node size offset)
	var sum = Vector2.ZERO
	for node in map_nodes:
		sum += node.position + (node.size / 2.0)
	
	var node_center = sum / map_nodes.size()
	var screen_center = size / 2.0
	var offset = screen_center - node_center
	
	for node in map_nodes:
		node.position += offset
	
	print("  Centered at screen (offset: %.1f, %.1f)" % [offset.x, offset.y])

# ============================================================================
# STEP 6.5: ROTATE TO HORIZONTAL
# ============================================================================

func rotate_to_horizontal():
	if map_nodes.size() < 2:
		return
	
	# Find two nodes that are furthest apart (using center positions)
	var max_distance = 0.0
	var node_a: MapNode2D = null
	var node_b: MapNode2D = null
	
	for i in range(map_nodes.size()):
		var pos_a = map_nodes[i].position + (map_nodes[i].size / 2.0)
		for j in range(i + 1, map_nodes.size()):
			var pos_b = map_nodes[j].position + (map_nodes[j].size / 2.0)
			var dist = pos_a.distance_to(pos_b)
			if dist > max_distance:
				max_distance = dist
				node_a = map_nodes[i]
				node_b = map_nodes[j]
	
	if node_a == null or node_b == null:
		return
	
	var pos_a_center = node_a.position + (node_a.size / 2.0)
	var pos_b_center = node_b.position + (node_b.size / 2.0)
	
	print("  Furthest nodes: %d and %d (distance: %.1f)" % [node_a.node_index, node_b.node_index, max_distance])
	
	# Calculate current angle between these nodes
	var direction = (pos_b_center - pos_a_center).normalized()
	var current_angle = atan2(direction.y, direction.x)
	
	# Desired angle is 0 (horizontal, pointing right)
	var rotation_angle = -current_angle
	
	# Calculate center of all nodes for rotation pivot (using center positions)
	var center = Vector2.ZERO
	for node in map_nodes:
		center += node.position + (node.size / 2.0)
	center /= map_nodes.size()
	
	# Rotate all nodes around center
	for node in map_nodes:
		var node_center = node.position + (node.size / 2.0)
		var offset = node_center - center
		var cos_a = cos(rotation_angle)
		var sin_a = sin(rotation_angle)
		var rotated_x = offset.x * cos_a - offset.y * sin_a
		var rotated_y = offset.x * sin_a + offset.y * cos_a
		var new_center = center + Vector2(rotated_x, rotated_y)
		node.position = new_center - (node.size / 2.0)
	
	var angle_degrees = rad_to_deg(rotation_angle)
	print("  Rotated by %.1f degrees around center (%.1f, %.1f)" % [angle_degrees, center.x, center.y])

# ============================================================================
# STEP 6.6: VERTICALLY CENTER NODES
# ============================================================================

func vertically_center_nodes():
	if map_nodes.size() == 0:
		print("  ERROR: No nodes to vertically center!")
		return
	
	# Find the bounding box (min and max Y positions)
	var min_y = INF
	var max_y = -INF
	for node in map_nodes:
		var node_top = node.position.y
		var node_bottom = node.position.y + node.size.y
		min_y = min(min_y, node_top)
		max_y = max(max_y, node_bottom)
	
	# Calculate center of bounding box
	var bounding_box_center_y = (min_y + max_y) / 2.0
	var screen_center_y = size.y / 2.0
	var y_offset = screen_center_y - bounding_box_center_y
	
	print("  DEBUG: Bounding box Y range: %.1f to %.1f (center: %.1f)" % [min_y, max_y, bounding_box_center_y])
	print("  DEBUG: Screen center Y: %.1f, Offset: %.1f" % [screen_center_y, y_offset])
	
	# Shift all nodes vertically
	for node in map_nodes:
		node.position.y += y_offset
	
	print("  Vertically centered (y offset: %.1f)" % y_offset)

# ============================================================================
# STEP 7: DELAUNAY TRIANGULATION
# ============================================================================

func generate_delaunay_connections():
	delaunay_edges.clear()
	
	if map_nodes.size() < 3:
		print("  Not enough nodes for triangulation")
		return
	
	# Use Godot's Geometry2D for Delaunay
	var points = PackedVector2Array()
	for node in map_nodes:
		points.append(node.global_position)
	
	var indices = Geometry2D.triangulate_delaunay(points)
	
	# Extract edges from triangles (3 edges per triangle)
	var edge_set = {}  # Use dict as set to avoid duplicates
	
	for i in range(0, indices.size(), 3):
		var idx_a = indices[i]
		var idx_b = indices[i + 1]
		var idx_c = indices[i + 2]
		
		# Add three edges (use sorted indices as key)
		var edges = [
			[min(idx_a, idx_b), max(idx_a, idx_b)],
			[min(idx_b, idx_c), max(idx_b, idx_c)],
			[min(idx_c, idx_a), max(idx_c, idx_a)]
		]
		
		for edge in edges:
			var key = str(edge[0]) + "_" + str(edge[1])
			if not edge_set.has(key):
				edge_set[key] = edge
	
	# Convert edge set to connections
	for edge in edge_set.values():
		var node_a = map_nodes[edge[0]]
		var node_b = map_nodes[edge[1]]
		
		node_a.connections.append(node_b)
		node_b.connections.append(node_a)
		
		delaunay_edges.append([node_a.position, node_b.position])
	
	print("  Created %d edges" % delaunay_edges.size())

# ============================================================================
# STEP 8: FILTER EDGES (OPTIONAL)
# ============================================================================

func filter_edges_by_distance():
	var max_dist = poisson_min_distance * max_connection_distance_multiplier
	var removed_count = 0
	
	print("  Filtering edges longer than %.1f units..." % max_dist)
	
	for node in map_nodes:
		var connections_to_remove = []
		for neighbor in node.connections:
			var dist = node.position.distance_to(neighbor.position)
			if dist > max_dist:
				connections_to_remove.append(neighbor)
		
		for neighbor in connections_to_remove:
			node.connections.erase(neighbor)
			neighbor.connections.erase(node)
			removed_count += 1
	
	# Rebuild edge list
	delaunay_edges.clear()
	var processed_edges = {}
	for node in map_nodes:
		for neighbor in node.connections:
			var key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
			if not processed_edges.has(key):
				processed_edges[key] = true
				delaunay_edges.append([node.position, neighbor.position])
	
	print("  Removed %d long edges, %d remaining" % [removed_count / 2, delaunay_edges.size()])

func filter_edges_by_angle():
	# Remove connections that create very small angles
	# If A-B and B-C are connected, don't allow A-C if angle ABC < threshold
	var min_angle_rad = deg_to_rad(min_angle_threshold_degrees)
	var removed_count = 0
	
	# Build a list of edges to potentially remove
	var edges_to_remove: Array = []  # Array of [node_a, node_b] pairs
	
	for node_a in map_nodes:
		for node_b in node_a.connections:
			# Skip if we've already marked this edge for removal
			var already_marked = false
			for edge in edges_to_remove:
				if (edge[0] == node_a and edge[1] == node_b) or (edge[0] == node_b and edge[1] == node_a):
					already_marked = true
					break
			if already_marked:
				continue
			
			# Check if this connection creates a very small angle
			# Find common neighbors of A and B
			for node_c in node_a.connections:
				if node_c == node_b:
					continue
				
				# If C is also connected to B, check the angle ABC
				if node_c in node_b.connections:
					var pos_a = node_a.position + (node_a.size / 2.0)
					var pos_b = node_b.position + (node_b.size / 2.0)
					var pos_c = node_c.position + (node_c.size / 2.0)
					
					# Calculate vectors from B
					var vec_ba = (pos_a - pos_b).normalized()
					var vec_bc = (pos_c - pos_b).normalized()
					
					# Calculate angle between vectors
					var dot_product = vec_ba.dot(vec_bc)
					dot_product = clamp(dot_product, -1.0, 1.0)  # Clamp for acos
					var angle = acos(dot_product)
					
					# If angle is too small, mark A-B for removal
					if angle < min_angle_rad:
						edges_to_remove.append([node_a, node_b])
						removed_count += 1
						break  # Only need to find one small angle to remove this edge
			
			# Also check from the other direction (angle BAC)
			if not already_marked:  # Only check if not already marked
				for node_c in node_b.connections:
					if node_c == node_a:
						continue
					
					# If C is also connected to A, check the angle BAC
					if node_c in node_a.connections:
						var pos_a = node_a.position + (node_a.size / 2.0)
						var pos_b = node_b.position + (node_b.size / 2.0)
						var pos_c = node_c.position + (node_c.size / 2.0)
						
						# Calculate vectors from A
						var vec_ab = (pos_b - pos_a).normalized()
						var vec_ac = (pos_c - pos_a).normalized()
						
						# Calculate angle between vectors
						var dot_product = vec_ab.dot(vec_ac)
						dot_product = clamp(dot_product, -1.0, 1.0)  # Clamp for acos
						var angle = acos(dot_product)
						
						# If angle is too small, mark A-B for removal
						if angle < min_angle_rad:
							# Check if already marked
							var already_marked_check = false
							for edge in edges_to_remove:
								if (edge[0] == node_a and edge[1] == node_b) or (edge[0] == node_b and edge[1] == node_a):
									already_marked_check = true
									break
							if not already_marked_check:
								edges_to_remove.append([node_a, node_b])
								removed_count += 1
							break
	
	# Remove the marked edges
	for edge in edges_to_remove:
		var node_a = edge[0]
		var node_b = edge[1]
		
		if node_b in node_a.connections:
			node_a.connections.erase(node_b)
		if node_a in node_b.connections:
			node_b.connections.erase(node_a)
	
	# Rebuild edge list after removal
	delaunay_edges.clear()
	var processed_edges = {}
	for node in map_nodes:
		for neighbor in node.connections:
			var key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
			if not processed_edges.has(key):
				processed_edges[key] = true
				var pos_a = node.position + (node.size / 2.0)
				var pos_b = neighbor.position + (neighbor.size / 2.0)
				delaunay_edges.append([pos_a, pos_b])
	
	print("  Removed %d edges with angles smaller than %.1f degrees" % [removed_count, min_angle_threshold_degrees])

# ============================================================================
# STEP 9: IDENTIFY COASTAL NODES
# ============================================================================

func identify_coastal_nodes():
	coastal_nodes.clear()
	coastal_connections.clear()
	
	# Clear all coastal flags
	for node in map_nodes:
		node.is_coastal = false
	
	# A boundary edge is one that belongs to only ONE triangle (or 0)
	# For each edge, count how many triangles contain it
	var checked_edges: Dictionary = {}
	var boundary_edge_data: Array = []  # Store boundary edges for verification
	
	# PASS 1: For each edge, count triangles that contain it
	for node_a in map_nodes:
		for node_b in node_a.connections:
			var edge_key = str(min(node_a.node_index, node_b.node_index)) + "_" + str(max(node_a.node_index, node_b.node_index))
			
			if edge_key in checked_edges:
				continue
			checked_edges[edge_key] = true
			
			# Count triangles containing this edge
			# A triangle exists if there's a node_c connected to BOTH node_a and node_b
			var triangle_count = 0
			var triangle_nodes: Array = []
			for node_c in node_a.connections:
				if node_c == node_b:
					continue
				# Check if node_c is also connected to node_b (forms triangle A-B-C)
				if node_c in node_b.connections:
					triangle_count += 1
					triangle_nodes.append(node_c.node_index)
					if triangle_count >= 2:
						break  # Interior edges have exactly 2 triangles
			
			# Boundary edges have triangle_count < 2 (0 or 1)
			if triangle_count < 2:
				node_a.is_coastal = true
				node_b.is_coastal = true
				coastal_connections.append([node_a, node_b])
				boundary_edge_data.append({
					"edge": edge_key,
					"node_a": node_a.node_index,
					"node_b": node_b.node_index,
					"triangle_count": triangle_count,
					"triangles": triangle_nodes
				})
	
	# PASS 2: Verification - ensure all nodes on boundary edges are marked
	# This catches any edge cases where marking might have failed
	var verification_fixes = 0
	for boundary in boundary_edge_data:
		var node_a_idx = boundary.node_a
		var node_b_idx = boundary.node_b
		
		# Find nodes by index
		var node_a_found: MapNode2D = null
		var node_b_found: MapNode2D = null
		for node in map_nodes:
			if node.node_index == node_a_idx:
				node_a_found = node
			if node.node_index == node_b_idx:
				node_b_found = node
		
		if node_a_found == null or node_b_found == null:
			_handle_generation_error("  ERROR: Could not find nodes for boundary edge %s" % boundary.edge)
			continue
		
		# Verify both nodes are marked (they should be, but double-check)
		if not node_a_found.is_coastal:
			print("  DEBUG: Node %d on boundary edge %s was not marked coastal! Fixing..." % [node_a_idx, boundary.edge])
			node_a_found.is_coastal = true
			verification_fixes += 1
		if not node_b_found.is_coastal:
			print("  DEBUG: Node %d on boundary edge %s was not marked coastal! Fixing..." % [node_b_idx, boundary.edge])
			node_b_found.is_coastal = true
			verification_fixes += 1
	
	# Collect all coastal nodes
	for node in map_nodes:
		if node.is_coastal:
			coastal_nodes.append(node)
			# Color coastal nodes white for visibility
			node.set_debug_color(Color.WHITE)
	
	if verification_fixes > 0:
		print("  WARNING: Fixed %d nodes that should have been marked coastal" % verification_fixes)
	
	# PASS 2.5: Fix coastal nodes with missing coastal edge connections
	# If a coastal node has fewer than 2 coastal neighbors, check its connections to other coastal nodes
	# and ensure those edges are marked as coastal (even if they have 2 triangles)
	var fixed_coastal_edges = 0
	for node in coastal_nodes:
		# Count how many coastal neighbors this node has
		var coastal_neighbor_count = 0
		for neighbor in node.connections:
			if neighbor.is_coastal:
				coastal_neighbor_count += 1
		
		# ONLY proceed if this coastal node has FEWER than 2 coastal neighbors
		if coastal_neighbor_count < 2:
			# Check all connections to other coastal nodes
			for neighbor in node.connections:
				if neighbor.is_coastal:
					# Check if this edge is already in coastal_connections
					var already_in_coastal = false
					for conn in coastal_connections:
						if (conn[0] == node and conn[1] == neighbor) or (conn[0] == neighbor and conn[1] == node):
							already_in_coastal = true
							break
					
					# If not, add it
					if not already_in_coastal:
						coastal_connections.append([node, neighbor])
						fixed_coastal_edges += 1
	
	if fixed_coastal_edges > 0:
		print("  Fixed %d missing coastal edge connections" % fixed_coastal_edges)
	
	# PASS 3: Remove interior loop nodes that were incorrectly marked as coastal
	# Interior loop nodes: coastal nodes that are ONLY connected to other coastal nodes
	# (they form interior loops, not the exterior boundary)
	# BUT: Don't remove nodes that have boundary edges - those are definitely on the exterior
	var interior_loop_nodes: Array[MapNode2D] = []
	
	for node in coastal_nodes:
		# Check if this node has ANY non-coastal neighbors
		var has_non_coastal_neighbor = false
		for neighbor in node.connections:
			if not neighbor.is_coastal:
				has_non_coastal_neighbor = true
				break
		
		# If it has NO non-coastal neighbors, it might be an interior loop node
		# But we need to verify it's not just a coastal node in a tight cluster
		if not has_non_coastal_neighbor:
			# CRITICAL: Check if this node has ANY boundary edges
			# If it has boundary edges, it's definitely on the exterior, not interior
			var has_boundary_edge = false
			for neighbor in node.connections:
				# Count triangles for this edge
				var triangle_count = 0
				for node_c in node.connections:
					if node_c == neighbor:
						continue
					if node_c in neighbor.connections:
						triangle_count += 1
						if triangle_count >= 2:
							break
				
				if triangle_count < 2:
					has_boundary_edge = true
					break
			
			# If it has boundary edges, it's definitely exterior - don't remove
			if has_boundary_edge:
				continue
			
			# Additional check: is this node "surrounded" by coastal nodes?
			# Count how many of its neighbors are coastal
			var coastal_neighbor_count = 0
			for neighbor in node.connections:
				if neighbor.is_coastal:
					coastal_neighbor_count += 1
			
			# If ALL neighbors are coastal AND it has 3+ neighbors AND no boundary edges, it's likely interior
			# (exterior boundary nodes typically have 1-2 coastal neighbors)
			if coastal_neighbor_count == node.connections.size() and node.connections.size() >= 3:
				interior_loop_nodes.append(node)
	
	# Remove interior loop nodes from coastal classification
	var removed_count = 0
	for node in interior_loop_nodes:
		node.is_coastal = false
		removed_count += 1
		
		# Remove their connections from coastal_connections
		var connections_to_remove: Array = []
		for i in range(coastal_connections.size() - 1, -1, -1):
			var conn = coastal_connections[i]
			if conn[0] == node or conn[1] == node:
				# Check if the OTHER node is truly coastal (has non-coastal neighbors)
				var other_node = conn[0] if conn[1] == node else conn[1]
				var other_has_non_coastal = false
				for neighbor in other_node.connections:
					if not neighbor.is_coastal:
						other_has_non_coastal = true
						break
				
				# Only remove if both nodes are interior loop nodes
				if not other_has_non_coastal:
					connections_to_remove.append(i)
		
		# Remove connections in reverse order to maintain indices
		for idx in connections_to_remove:
			coastal_connections.remove_at(idx)
	
	# Re-collect coastal nodes after removal
	coastal_nodes.clear()
	for node in map_nodes:
		if node.is_coastal:
			coastal_nodes.append(node)
			node.set_debug_color(Color.WHITE)
	
	if removed_count > 0:
		print("  Removed %d interior loop nodes incorrectly marked as coastal" % removed_count)
	
	print("  Identified %d coastal nodes with %d coastal connections (found %d boundary edges)" % [coastal_nodes.size(), coastal_connections.size(), boundary_edge_data.size()])
	
	# PASS 2.75: Identify interior loops
	identify_interior_loops()
	
	# Generate expanded coast lines after identifying coastal nodes
	if coastal_nodes.size() >= 2:
		generate_expanded_coast()

# ============================================================================
# INTERIOR LOOP IDENTIFICATION
# ============================================================================

func identify_interior_loops():
	# Build adjacency map from coastal connections
	var coastal_adjacency: Dictionary = {}  # node_index -> Array[MapNode2D]
	
	for connection in coastal_connections:
		var node_a = connection[0]
		var node_b = connection[1]
		
		if not coastal_adjacency.has(node_a.node_index):
			coastal_adjacency[node_a.node_index] = []
		if not coastal_adjacency.has(node_b.node_index):
			coastal_adjacency[node_b.node_index] = []
		
		if node_b not in coastal_adjacency[node_a.node_index]:
			coastal_adjacency[node_a.node_index].append(node_b)
		if node_a not in coastal_adjacency[node_b.node_index]:
			coastal_adjacency[node_b.node_index].append(node_a)
	
	# Find all cycles/loops in the coastal graph using DFS
	var all_loops: Array = []  # Array of Arrays of node_indices
	var visited_edges: Dictionary = {}
	
	# Try to find cycles starting from each node
	for start_node in coastal_nodes:
		if not coastal_adjacency.has(start_node.node_index):
			continue
		
		var path: Array = [start_node.node_index]
		var found_loop = find_cycle_dfs(start_node, start_node, path, coastal_adjacency, visited_edges, {})
		
		if found_loop.size() >= 3:
			# Check if this loop is already found (same nodes, different order)
			var is_duplicate = false
			for existing_loop in all_loops:
				if are_loops_same(found_loop, existing_loop):
					is_duplicate = true
					break
			
			if not is_duplicate:
				all_loops.append(found_loop)
	
	# Find the largest loop (main boundary)
	if all_loops.size() == 0:
		print("  No loops found in coastal connections")
		return
	
	var largest_loop: Array = all_loops[0]
	var largest_size = all_loops[0].size()
	for loop in all_loops:
		if loop.size() > largest_size:
			largest_loop = loop
			largest_size = loop.size()
	
	print("  Found %d loops, largest loop has %d nodes (main boundary)" % [all_loops.size(), largest_size])
	
	# Identify interior loops (loops that share nodes with main boundary but are smaller)
	var interior_loops: Array = []
	var main_boundary_nodes: Dictionary = {}
	for node_idx in largest_loop:
		main_boundary_nodes[node_idx] = true
	
	for loop in all_loops:
		if loop == largest_loop:
			continue  # Skip the main boundary
		
		# Check if this loop shares any nodes with the main boundary
		var shares_nodes = false
		for node_idx in loop:
			if main_boundary_nodes.has(node_idx):
				shares_nodes = true
				break
		
		if shares_nodes:
			interior_loops.append(loop)
			print("  INTERIOR LOOP FOUND: %s (shares nodes with main boundary)" % str(loop))
	
	if interior_loops.size() > 0:
		print("  Identified %d interior loops" % interior_loops.size())
	else:
		print("  No interior loops found")

func find_cycle_dfs(current: MapNode2D, start: MapNode2D, path: Array, adjacency: Dictionary, visited_edges: Dictionary, path_set: Dictionary):
	# Base case: found cycle back to start
	if current == start and path.size() >= 3:
		return path.duplicate()
	
	# Explore neighbors
	if not adjacency.has(current.node_index):
		return []
	
	for neighbor in adjacency[current.node_index]:
		var neighbor_idx = neighbor.node_index
		
		# Skip if already in path (except if it's the start and we're closing the cycle)
		if path_set.has(neighbor_idx):
			if neighbor == start and path.size() >= 2:
				# Closing the cycle
				var cycle = path.duplicate()
				cycle.append(neighbor_idx)
				return cycle
			continue
		
		# Mark edge as visited
		var edge_key = str(min(current.node_index, neighbor_idx)) + "_" + str(max(current.node_index, neighbor_idx))
		if edge_key in visited_edges:
			continue
		visited_edges[edge_key] = true
		
		# Recurse
		path.append(neighbor_idx)
		path_set[neighbor_idx] = true
		var result = find_cycle_dfs(neighbor, start, path, adjacency, visited_edges, path_set)
		if result.size() > 0:
			return result
		path.pop_back()
		path_set.erase(neighbor_idx)
		visited_edges.erase(edge_key)
	
	return []

func are_loops_same(loop1: Array, loop2: Array) -> bool:
	# Check if two loops contain the same nodes (order doesn't matter)
	if loop1.size() != loop2.size():
		return false
	
	var set1: Dictionary = {}
	var set2: Dictionary = {}
	for idx in loop1:
		set1[idx] = true
	for idx in loop2:
		set2[idx] = true
	
	if set1.size() != set2.size():
		return false
	
	for idx in set1.keys():
		if not set2.has(idx):
			return false
	
	return true

# ============================================================================
# STEP 9.5: GENERATE EXPANDED COAST
# ============================================================================

func generate_expanded_coast():
	expanded_coast_lines.clear()
	
	if coastal_connections.size() == 0:
		return
	
	# Calculate map center for fallback
	var map_center = Vector2.ZERO
	for node in map_nodes:
		map_center += node.position + (node.size / 2.0)
	map_center /= map_nodes.size()
	
	# PASS 1: ALL coastal nodes with 3+ connections
	if enable_pass1:
		calculate_away_directions_pass1()
	
	# PASS 2: Coastal nodes with exactly 2 connections
	if enable_pass2:
		calculate_away_directions_pass2()
	
	# Validate that all coastal nodes have been processed
	validate_all_coastal_nodes_processed()
	
	# Use away_directions to calculate expanded positions
	var expanded_positions: Dictionary = {}  # node_index -> expanded Vector2
	
	for node in coastal_nodes:
		var node_center = node.position + (node.size / 2.0)
		# Use the stored away_direction angle
		var away_vector = Vector2(cos(node.away_direction), sin(node.away_direction))
		var expanded_pos = node_center + away_vector * coast_expansion_distance
		expanded_positions[node.node_index] = expanded_pos
	
	# Third pass: create lines between expanded vertices using original connections
	for connection in coastal_connections:
		var node_a = connection[0]
		var node_b = connection[1]
		
		var expanded_a = expanded_positions.get(node_a.node_index)
		var expanded_b = expanded_positions.get(node_b.node_index)
		
		if expanded_a != null and expanded_b != null:
			expanded_coast_lines.append([expanded_a, expanded_b])
	
	print("  Generated %d expanded coast lines from %d coastal nodes (%d connections)" % [expanded_coast_lines.size(), coastal_nodes.size(), coastal_connections.size()])

# ============================================================================
# COAST EXPANSION: AWAY DIRECTION CALCULATION
# ============================================================================

func calculate_away_directions_pass1():
	# PASS 1: ALL coastal nodes with 3+ connections
	print("  PASS 1: Processing ALL coastal nodes with 3+ connections...")
	var processed_count = 0
	for node in coastal_nodes:
		if node.connections.size() < 3:
			continue
		
		# Find coastal neighbors
		var coastal_neighbors: Array[MapNode2D] = []
		var non_coastal_neighbors: Array[MapNode2D] = []
		
		for neighbor in node.connections:
			if neighbor.is_coastal:
				coastal_neighbors.append(neighbor)
			else:
				non_coastal_neighbors.append(neighbor)
		
		processed_count += 1
		print("    PASS 1: Node %d (connections=%d, coastal_neighbors=%d, non_coastal_neighbors=%d)" % [node.node_index, node.connections.size(), coastal_neighbors.size(), non_coastal_neighbors.size()])
		
		var node_center = node.position + (node.size / 2.0)
		var away_angle: float
		
		if coastal_neighbors.size() == 2:
			# Case: Exactly 2 coastal neighbors (original logic)
			var coastal_1 = coastal_neighbors[0]
			var coastal_2 = coastal_neighbors[1]
			
			var pos_1 = coastal_1.position + (coastal_1.size / 2.0)
			var pos_2 = coastal_2.position + (coastal_2.size / 2.0)
			
			# Calculate angles to coastal neighbors
			var vec_1 = (pos_1 - node_center).normalized()
			var vec_2 = (pos_2 - node_center).normalized()
			var angle_1 = atan2(vec_1.y, vec_1.x)
			var angle_2 = atan2(vec_2.y, vec_2.x)
			
			# Normalize angles to 0-2π range
			if angle_1 < 0:
				angle_1 += TAU
			if angle_2 < 0:
				angle_2 += TAU
			
			# Determine which arc contains non-coastal nodes
			var arc_1_start = min(angle_1, angle_2)
			var arc_1_end = max(angle_1, angle_2)
			var arc_1_span = arc_1_end - arc_1_start
			var arc_2_span = TAU - arc_1_span
			
			# Check which arc has non-coastal nodes
			var non_coastal_in_arc1 = false
			for non_coastal in non_coastal_neighbors:
				var pos_nc = non_coastal.position + (non_coastal.size / 2.0)
				var vec_nc = (pos_nc - node_center).normalized()
				var angle_nc = atan2(vec_nc.y, vec_nc.x)
				if angle_nc < 0:
					angle_nc += TAU
				
				# Check if angle_nc is in arc_1
				if angle_nc >= arc_1_start and angle_nc <= arc_1_end:
					non_coastal_in_arc1 = true
					break
			
			# Away direction is midpoint of the arc WITHOUT non-coastal nodes
			if non_coastal_in_arc1:
				# Use arc 2 (the longer arc, wrapping around)
				away_angle = (arc_1_end + arc_2_span / 2.0)
				if away_angle >= TAU:
					away_angle -= TAU
			else:
				# Use arc 1 (the shorter arc between the two coastal nodes)
				away_angle = arc_1_start + arc_1_span / 2.0
		
		elif coastal_neighbors.size() >= 3:
			# Case: 3+ coastal neighbors
			# Find the 2 coastal neighbors where the EDGE is also coastal (in coastal_connections)
			var coastal_neighbors_with_coastal_edges: Array[MapNode2D] = []
			print("      Node %d: Checking %d coastal neighbors for coastal edges..." % [node.node_index, coastal_neighbors.size()])
			for neighbor in coastal_neighbors:
				# Check if the edge between node and neighbor is in coastal_connections
				var edge_is_coastal = false
				for connection in coastal_connections:
					if (connection[0] == node and connection[1] == neighbor) or (connection[0] == neighbor and connection[1] == node):
						edge_is_coastal = true
						break
				
				print("        Neighbor %d: edge_is_coastal=%s" % [neighbor.node_index, edge_is_coastal])
				if edge_is_coastal:
					coastal_neighbors_with_coastal_edges.append(neighbor)
			
			# There should be exactly 2 coastal neighbors with coastal edges
			if coastal_neighbors_with_coastal_edges.size() != 2:
				_handle_generation_error("Node %d has %d coastal neighbors with coastal edges (expected 2)" % [node.node_index, coastal_neighbors_with_coastal_edges.size()])
				print("      ERROR: Expected 2, got %d. Using fallback (first 2 coastal neighbors)" % coastal_neighbors_with_coastal_edges.size())
				# Fallback: use first two coastal neighbors
				coastal_neighbors_with_coastal_edges = [coastal_neighbors[0], coastal_neighbors[1]]
			
			var coastal_1 = coastal_neighbors_with_coastal_edges[0]
			var coastal_2 = coastal_neighbors_with_coastal_edges[1]
			print("      SELECTED: Using neighbors %d and %d for arc calculation" % [coastal_1.node_index, coastal_2.node_index])
			
			var pos_1 = coastal_1.position + (coastal_1.size / 2.0)
			var pos_2 = coastal_2.position + (coastal_2.size / 2.0)
			
			var vec_1 = (pos_1 - node_center).normalized()
			var vec_2 = (pos_2 - node_center).normalized()
			var angle_1 = atan2(vec_1.y, vec_1.x)
			var angle_2 = atan2(vec_2.y, vec_2.x)
			
			if angle_1 < 0:
				angle_1 += TAU
			if angle_2 < 0:
				angle_2 += TAU
			
			var arc_1_start = min(angle_1, angle_2)
			var arc_1_end = max(angle_1, angle_2)
			var arc_1_span = arc_1_end - arc_1_start
			var arc_2_span = TAU - arc_1_span
			
			# Check ALL other neighbors (coastal or not) to see which arc they fall in
			# Exclude the two coastal neighbors we're using for the arc
			# Since the two arcs cover the full circle, an angle MUST be in one or the other
			var other_neighbors_in_arc1 = false
			var other_neighbors_in_arc2 = false
			
			print("      Checking other neighbors for arc classification:")
			print("      Arc 1 range: %.1f° to %.1f°" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end)])
			print("      Arc 2 range: %.1f° to %.1f° (wrapping)" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU)])
			
			for other_neighbor in node.connections:
				if other_neighbor == coastal_1 or other_neighbor == coastal_2:
					continue  # Skip the two we're using for the arc
				
				var pos_other = other_neighbor.position + (other_neighbor.size / 2.0)
				var vec_other = (pos_other - node_center).normalized()
				var angle_other = atan2(vec_other.y, vec_other.x)
				if angle_other < 0:
					angle_other += TAU
				
				var angle_other_deg = rad_to_deg(angle_other)
				
				# Check which arc this angle falls into
				# Arc 1 is the direct range [arc_1_start, arc_1_end]
				# Arc 2 is the wrapping range (everything else)
				var in_arc1 = (angle_other >= arc_1_start and angle_other <= arc_1_end)
				
				print("        Neighbor %d: angle=%.1f°, in_arc1=%s (check: %.1f >= %.1f AND %.1f <= %.1f)" % [
					other_neighbor.node_index,
					angle_other_deg,
					in_arc1,
					angle_other_deg,
					rad_to_deg(arc_1_start),
					angle_other_deg,
					rad_to_deg(arc_1_end)
				])
				
				if in_arc1:
					other_neighbors_in_arc1 = true
					print("          → Classified as ARC 1")
				else:
					# Must be in arc 2 (the two arcs cover the full circle)
					other_neighbors_in_arc2 = true
					print("          → Classified as ARC 2")
			
			# Calculate candidate angles
			var candidate_arc1 = arc_1_start + arc_1_span / 2.0
			var candidate_arc2 = (arc_1_end + arc_2_span / 2.0)
			if candidate_arc2 >= TAU:
				candidate_arc2 -= TAU
			
			print("      Candidate angles: Arc1_midpoint=%.1f°, Arc2_midpoint=%.1f°" % [rad_to_deg(candidate_arc1), rad_to_deg(candidate_arc2)])
			print("      Neighbors in arc1: %s, Neighbors in arc2: %s" % [other_neighbors_in_arc1, other_neighbors_in_arc2])
			
			# Pick the midpoint of the arc OPPOSITE to where other neighbors lie
			# If neighbors are in arc 1, use arc 2's midpoint
			# If neighbors are in arc 2, use arc 1's midpoint
			if other_neighbors_in_arc1 and not other_neighbors_in_arc2:
				# Neighbors are in arc 1, use arc 2
				away_angle = candidate_arc2
				print("      DECISION: Neighbors in ARC 1 → Use ARC 2 candidate = %.1f°" % rad_to_deg(away_angle))
			elif other_neighbors_in_arc2 and not other_neighbors_in_arc1:
				# Neighbors are in arc 2, use arc 1
				away_angle = candidate_arc1
				print("      DECISION: Neighbors in ARC 2 → Use ARC 1 candidate = %.1f°" % rad_to_deg(away_angle))
			else:
				# ERROR: Neighbors in both arcs or neither - this should be impossible
				_handle_generation_error("Node %d: ERROR - Neighbors found in both arcs or neither! arc1=%s, arc2=%s" % [node.node_index, other_neighbors_in_arc1, other_neighbors_in_arc2])
				print("      ERROR: Cannot determine which arc neighbors are in!")
				print("      Arc 1: %.1f° to %.1f°" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end)])
				print("      Arc 2: %.1f° to %.1f° (wrapping)" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU)])
				# Fallback: use arc 1 midpoint
				away_angle = candidate_arc1
				print("      FALLBACK: Using ARC 1 candidate = %.1f°" % rad_to_deg(away_angle))
		
		else:
			# Case: 0-1 coastal neighbors - use non-coastal neighbors to determine away direction
			# Calculate average direction away from all neighbors
			var sum_vec = Vector2.ZERO
			for neighbor in node.connections:
				var pos_n = neighbor.position + (neighbor.size / 2.0)
				var vec_n = (node_center - pos_n).normalized()
				sum_vec += vec_n
			
			if sum_vec.length() > 0.001:
				away_angle = atan2(sum_vec.y, sum_vec.x)
				if away_angle < 0:
					away_angle += TAU
			else:
				# Fallback: random direction
				away_angle = randf() * TAU
		
		# SET THE AWAY DIRECTION - DO NOT SKIP THIS
		node.away_direction = away_angle
		print("      → Set away_direction=%.1f° for node %d" % [rad_to_deg(away_angle), node.node_index])
	
	print("  PASS 1: Processed %d nodes" % processed_count)

func calculate_away_directions_pass2():
	# PASS 2: Coastal nodes with exactly 2 connections
	for node in coastal_nodes:
		if node.connections.size() != 2:
			continue
		
		print("  PASS 2: Node %d (2 connections)" % node.node_index)
		
		var node_center = node.position + (node.size / 2.0)
		var neighbor_1 = node.connections[0]
		var neighbor_2 = node.connections[1]
		
		var pos_1 = neighbor_1.position + (neighbor_1.size / 2.0)
		var pos_2 = neighbor_2.position + (neighbor_2.size / 2.0)
		
		# Calculate angles to neighbors
		var vec_1 = (pos_1 - node_center).normalized()
		var vec_2 = (pos_2 - node_center).normalized()
		var angle_1 = atan2(vec_1.y, vec_1.x)
		var angle_2 = atan2(vec_2.y, vec_2.x)
		
		# Normalize angles
		if angle_1 < 0:
			angle_1 += TAU
		if angle_2 < 0:
			angle_2 += TAU
		
		print("    Neighbor 1 (node %d): angle=%.1f° (%.2f rad), is_coastal=%s, away_direction=%.1f°" % [neighbor_1.node_index, rad_to_deg(angle_1), angle_1, neighbor_1.is_coastal, rad_to_deg(neighbor_1.away_direction) if neighbor_1.away_direction != 0.0 else 0.0])
		print("    Neighbor 2 (node %d): angle=%.1f° (%.2f rad), is_coastal=%s, away_direction=%.1f°" % [neighbor_2.node_index, rad_to_deg(angle_2), angle_2, neighbor_2.is_coastal, rad_to_deg(neighbor_2.away_direction) if neighbor_2.away_direction != 0.0 else 0.0])
		
		# Calculate both candidate away angles
		var arc_1_start = min(angle_1, angle_2)
		var arc_1_end = max(angle_1, angle_2)
		var arc_1_span = arc_1_end - arc_1_start
		var arc_2_span = TAU - arc_1_span
		
		var candidate_1 = arc_1_start + arc_1_span / 2.0  # Midpoint of arc 1
		var candidate_2 = arc_1_end + arc_2_span / 2.0   # Midpoint of arc 2
		if candidate_2 >= TAU:
			candidate_2 -= TAU
		
		print("    Arc 1: %.1f° to %.1f° (span=%.1f°), candidate=%.1f°" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end), rad_to_deg(arc_1_span), rad_to_deg(candidate_1)])
		print("    Arc 2: %.1f° to %.1f° (span=%.1f°), candidate=%.1f°" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU), rad_to_deg(arc_2_span), rad_to_deg(candidate_2)])
		
		# Find which candidate is closest to neighboring coastal nodes' away_directions
		var use_candidate_1 = true
		var selection_reason = ""
		
		# Check if we have neighboring coastal nodes with away_directions already set
		var has_coastal_neighbors_with_away = false
		var total_distance_to_candidate_1 = 0.0
		var total_distance_to_candidate_2 = 0.0
		var neighbor_count = 0
		
		print("    Checking neighbors' away_directions:")
		for neighbor in node.connections:
			var away_str = "%.1f° (raw=%.4f)" % [rad_to_deg(neighbor.away_direction), neighbor.away_direction] if neighbor.away_direction != 0.0 else "NOT SET (0.0)"
			print("      Neighbor %d: is_coastal=%s, away_direction=%s" % [neighbor.node_index, neighbor.is_coastal, away_str])
			
			if neighbor.is_coastal and neighbor.away_direction != 0.0:  # away_direction is set (non-zero)
				has_coastal_neighbors_with_away = true
				var neighbor_away = neighbor.away_direction
				if neighbor_away < 0:
					neighbor_away += TAU
				
				# Calculate distance from neighbor's away_direction to each candidate
				var dist_to_c1 = abs(neighbor_away - candidate_1)
				if dist_to_c1 > PI:
					dist_to_c1 = TAU - dist_to_c1
				
				var dist_to_c2 = abs(neighbor_away - candidate_2)
				if dist_to_c2 > PI:
					dist_to_c2 = TAU - dist_to_c2
				
				total_distance_to_candidate_1 += dist_to_c1
				total_distance_to_candidate_2 += dist_to_c2
				neighbor_count += 1
				
				print("        → USING: away_direction=%.1f°, dist_to_c1=%.1f°, dist_to_c2=%.1f°" % [rad_to_deg(neighbor_away), rad_to_deg(dist_to_c1), rad_to_deg(dist_to_c2)])
			else:
				if neighbor.is_coastal:
					print("        → SKIPPING: is_coastal but away_direction not set (value=%.4f)" % neighbor.away_direction)
				else:
					print("        → SKIPPING: not coastal")
		
		if has_coastal_neighbors_with_away:
			# Use the candidate that's closer to neighboring away_directions
			use_candidate_1 = total_distance_to_candidate_1 < total_distance_to_candidate_2
			selection_reason = "closer to neighboring away_directions (total dist: c1=%.1f°, c2=%.1f°)" % [rad_to_deg(total_distance_to_candidate_1), rad_to_deg(total_distance_to_candidate_2)]
			print("    DECISION: Using away_direction comparison - total_dist_c1=%.1f°, total_dist_c2=%.1f°" % [rad_to_deg(total_distance_to_candidate_1), rad_to_deg(total_distance_to_candidate_2)])
		else:
			# Fallback: if one neighbor is non-coastal, use the arc away from it
			var non_coastal = neighbor_1 if not neighbor_1.is_coastal else (neighbor_2 if not neighbor_2.is_coastal else null)
			if non_coastal != null:
				var pos_nc = non_coastal.position + (non_coastal.size / 2.0)
				var vec_nc = (pos_nc - node_center).normalized()
				var angle_nc = atan2(vec_nc.y, vec_nc.x)
				if angle_nc < 0:
					angle_nc += TAU
				
				var non_coastal_in_arc1 = (angle_nc >= arc_1_start and angle_nc <= arc_1_end)
				use_candidate_1 = not non_coastal_in_arc1  # Use opposite arc
				selection_reason = "non-coastal neighbor %d at %.1f° is %s arc_1, using %s arc" % [non_coastal.node_index, rad_to_deg(angle_nc), "in" if non_coastal_in_arc1 else "not in", "opposite" if non_coastal_in_arc1 else "same"]
				print("    DECISION: Using non-coastal fallback - neighbor %d at angle=%.1f°" % [non_coastal.node_index, rad_to_deg(angle_nc)])
			else:
				selection_reason = "no away_directions available and both neighbors are coastal, defaulting to candidate_1"
				print("    DECISION: FALLBACK - No away_directions and both neighbors are coastal")
		
		# Set the chosen away direction
		var chosen_candidate = candidate_1 if use_candidate_1 else candidate_2
		node.away_direction = chosen_candidate
		
		print("    SELECTED: Candidate %d (%.1f°) - %s" % [1 if use_candidate_1 else 2, rad_to_deg(chosen_candidate), selection_reason])
		print("")

func validate_all_coastal_nodes_processed():
	# Ensure all coastal nodes have been processed (have away_direction set)
	var unprocessed_nodes: Array[MapNode2D] = []
	for node in coastal_nodes:
		if node.away_direction == 0.0:
			unprocessed_nodes.append(node)
	
	if unprocessed_nodes.size() > 0:
		_handle_generation_error("ERROR: %d coastal nodes were not processed!" % unprocessed_nodes.size())
		print("  Unprocessed coastal nodes:")
		for node in unprocessed_nodes:
			print("    Node %d: connections=%d" % [node.node_index, node.connections.size()])
	else:
		print("  ✓ All %d coastal nodes have been processed" % coastal_nodes.size())

# ============================================================================
# STEP 10: BUILD ASTAR2D
# ============================================================================

func build_astar_graph():
	astar = AStar2D.new()
	
	# Add all nodes
	for node in map_nodes:
		astar.add_point(node.node_index, node.position)
	
	# Add all connections
	for node in map_nodes:
		for neighbor in node.connections:
			if not astar.are_points_connected(node.node_index, neighbor.node_index):
				astar.connect_points(node.node_index, neighbor.node_index)
	
	print("  Built AStar2D with %d points" % astar.get_point_count())

# ============================================================================
# STEP 11: IDENTIFY POINTS OF INTEREST
# ============================================================================

func identify_points_of_interest():
	if map_nodes.size() < 3:
		return
	
	# Find most isolated node (furthest from all others)
	var max_min_distance = 0.0
	var most_isolated: MapNode2D = null
	
	for node in map_nodes:
		if node.is_coastal:
			continue
		
		var min_dist_to_others = INF
		for other in map_nodes:
			if other == node:
				continue
			var dist = node.position.distance_to(other.position)
			if dist < min_dist_to_others:
				min_dist_to_others = dist
		
		if min_dist_to_others > max_min_distance:
			max_min_distance = min_dist_to_others
			most_isolated = node
	
	if most_isolated:
		most_isolated.is_poi = true
		most_isolated.poi_type = "lonely_mountain"
		print("  Identified lonely mountain at node %d" % most_isolated.node_index)

# ============================================================================
# STEP 12: CREATE REGIONS
# ============================================================================

func create_regions():
	# Simple region assignment: divide nodes into N groups
	# More sophisticated algorithm could use graph-based region growing
	
	var interior_nodes = []
	for node in map_nodes:
		if not node.is_coastal:
			interior_nodes.append(node)
	
	if interior_nodes.size() == 0:
		return
	
	# Pick random seed nodes
	var seeds = []
	for i in range(min(region_count, interior_nodes.size())):
		var random_node = interior_nodes[randi() % interior_nodes.size()]
		while random_node in seeds:
			random_node = interior_nodes[randi() % interior_nodes.size()]
		seeds.append(random_node)
		random_node.region_id = i
	
	# Assign all other nodes to nearest seed
	for node in interior_nodes:
		if node.region_id >= 0:
			continue
		
		var min_dist = INF
		var nearest_region = 0
		
		for i in range(seeds.size()):
			var dist = node.position.distance_to(seeds[i].position)
			if dist < min_dist:
				min_dist = dist
				nearest_region = i
		
		node.region_id = nearest_region
	
	# Colorize regions
	colorize_regions(region_count)
	
	print("  Created %d regions" % region_count)

func colorize_regions(num_regions: int):
	# All nodes get the configured node color (export property)
	# Color ALL nodes (including coastal nodes that might not have region_id)
	for node in map_nodes:
		if not node.is_mountain:  # Mountains keep their color
			# Coastal nodes also get the node color
			node.set_region_color(node_base_color)

# ============================================================================
# STEP 12.5: GENERATE MOUNTAINS AT REGION BORDERS
# ============================================================================

func generate_mountains_at_borders():
	# Step 1: Find all border nodes (nodes connected to nodes in different regions)
	var border_nodes: Array[MapNode2D] = []
	
	for node in map_nodes:
		if node.region_id < 0:
			continue
		
		for neighbor in node.connections:
			if neighbor.region_id >= 0 and neighbor.region_id != node.region_id:
				if not node in border_nodes:
					border_nodes.append(node)
				break
	
	print("  Total border nodes found: %d" % border_nodes.size())
	
	# Step 2: Group border nodes into segments between region pairs
	# Dictionary: "regionA_regionB" -> Array of nodes in that border segment
	var border_segments: Dictionary = {}
	
	for node in border_nodes:
		for neighbor in node.connections:
			if neighbor.region_id >= 0 and neighbor.region_id != node.region_id:
				var region_a = min(node.region_id, neighbor.region_id)
				var region_b = max(node.region_id, neighbor.region_id)
				var key = str(region_a) + "_" + str(region_b)
				
				if not border_segments.has(key):
					border_segments[key] = []
				
				if not node in border_segments[key]:
					border_segments[key].append(node)
				break
	
	# Step 3: Count nodes per region (to determine which region is larger)
	var region_node_counts: Dictionary = {}
	for node in map_nodes:
		if node.region_id >= 0:
			if not region_node_counts.has(node.region_id):
				region_node_counts[node.region_id] = 0
			region_node_counts[node.region_id] += 1
	
	# Step 3.5: Count how many border segments each region has
	var region_border_counts: Dictionary = {}  # region_id -> count of borders
	for key in border_segments.keys():
		var region_a_id = int(key.split("_")[0])
		var region_b_id = int(key.split("_")[1])
		
		if not region_border_counts.has(region_a_id):
			region_border_counts[region_a_id] = 0
		if not region_border_counts.has(region_b_id):
			region_border_counts[region_b_id] = 0
		
		region_border_counts[region_a_id] += 1
		region_border_counts[region_b_id] += 1
	
	# Step 4: Assign rolls with rules
	var border_keys = border_segments.keys()
	if border_keys.size() == 0:
		print("  No border segments found")
		return
	
	print("  Found %d border segments between regions" % border_keys.size())
	
	# Dictionary to store assigned rolls: key -> roll
	var assigned_rolls: Dictionary = {}
	var available_for_distribution: Array = []  # Keys that can get normal distribution
	
	# Rule A: If a region only borders one other region, that border MUST be 2 or 3
	for key in border_keys:
		var region_a_id = int(key.split("_")[0])
		var region_b_id = int(key.split("_")[1])
		
		var borders_a = region_border_counts.get(region_a_id, 0)
		var borders_b = region_border_counts.get(region_b_id, 0)
		
		if borders_a == 1 or borders_b == 1:
			# This border MUST be 2 or 3 (randomly choose)
			var forced_roll = 2 + (randi() % 2)  # Either 2 or 3
			assigned_rolls[key] = forced_roll
			print("    Border Region %d <-> Region %d: FORCED to roll=%d (one region has only 1 border)" % [region_a_id, region_b_id, forced_roll])
		else:
			available_for_distribution.append(key)
	
	# Rule B: Type 1 (full wall) can ONLY happen if BOTH regions border more than 2 regions
	# Process borders sequentially and update counts dynamically as type 1s are assigned
	var segment_lengths: Array = []  # Array of [key, length]
	for key in available_for_distribution:
		var segment_nodes = border_segments[key]
		segment_lengths.append([key, segment_nodes.size()])
	
	# Sort by length (longest first)
	segment_lengths.sort_custom(func(a, b): return a[1] > b[1])
	
	# Step 5: Process borders sequentially with dynamic count updates
	var num_remaining = available_for_distribution.size()
	var count_0_used = 0
	var count_1_used = 0
	var target_count_0 = min(2, max(0, num_remaining / 8))
	var target_count_1 = min(2, max(0, num_remaining / 8))
	
	# Process each border segment sequentially
	for item in segment_lengths:
		var key = item[0]
		var length = item[1]
		var region_a_id = int(key.split("_")[0])
		var region_b_id = int(key.split("_")[1])
		
		# Check current border counts (updated dynamically)
		var borders_a = region_border_counts.get(region_a_id, 0)
		var borders_b = region_border_counts.get(region_b_id, 0)
		
		var roll = -1
		
		# Determine roll based on current counts and distribution targets
		if length <= 5 and count_0_used < target_count_0:
			# Short border, assign 0
			roll = 0
			count_0_used += 1
		elif borders_a > 2 and borders_b > 2 and count_1_used < target_count_1:
			# Both regions have > 2 borders, can assign type 1
			roll = 1
			count_1_used += 1
			# Update border counts: this border no longer counts as a connection
			# (when type 1 is assigned, both regions lose one border count)
			if region_border_counts.has(region_a_id):
				region_border_counts[region_a_id] = max(0, region_border_counts[region_a_id] - 1)
			if region_border_counts.has(region_b_id):
				region_border_counts[region_b_id] = max(0, region_border_counts[region_b_id] - 1)
		else:
			# Assign 2 or 3 (randomly)
			roll = 2 + (randi() % 2)
		
		assigned_rolls[key] = roll
	
	# Debug: Count roll distribution
	var roll_counts = [0, 0, 0, 0]
	for key in assigned_rolls.keys():
		roll_counts[assigned_rolls[key]] += 1
	print("  Roll distribution: 0=%d, 1=%d, 2=%d, 3=%d" % [roll_counts[0], roll_counts[1], roll_counts[2], roll_counts[3]])
	
	# Step 6: Apply rolls to border segments
	var mountains_created = 0
	
	for key in border_keys:
		var segment_nodes = border_segments[key]
		if segment_nodes.size() == 0:
			continue
		
		var roll = assigned_rolls[key]
		var region_a_id = int(key.split("_")[0])
		var region_b_id = int(key.split("_")[1])
		print("    Border Region %d <-> Region %d: Roll=%d, %d nodes" % [region_a_id, region_b_id, roll, segment_nodes.size()])
		
		if roll == 0:
			continue  # No mountains
		
		# Determine which region's nodes become mountains (choose larger region)
		
		var count_a = region_node_counts.get(region_a_id, 0)
		var count_b = region_node_counts.get(region_b_id, 0)
		
		# Choose region with more nodes (if tied, choose region_a)
		var target_region_id = region_a_id if count_a >= count_b else region_b_id
		
		# Filter segment nodes to only those in the target region
		var target_nodes: Array[MapNode2D] = []
		for node in segment_nodes:
			if node.region_id == target_region_id:
				target_nodes.append(node)
		
		if target_nodes.size() == 0:
			continue
		
		# Sort nodes by position to find first/last
		target_nodes.sort_custom(func(a, b): return a.position.x < b.position.x or (a.position.x == b.position.x and a.position.y < b.position.y))
		
		# Apply mountain pattern based on roll
		var nodes_made_mountains = 0
		if roll == 1:
			# All nodes become mountains
			for node in target_nodes:
				node.is_mountain = true
				node.set_mountain_color()
				node.become_mountain()
				nodes_made_mountains += 1
		
		elif roll == 2:
			# All except first and last
			if target_nodes.size() <= 2:
				print("      → Skipped (need 3+ nodes, got %d)" % target_nodes.size())
				continue  # Need at least 3 nodes
			
			for i in range(1, target_nodes.size() - 1):
				target_nodes[i].is_mountain = true
				target_nodes[i].set_mountain_color()
				target_nodes[i].become_mountain()
				nodes_made_mountains += 1
		
		elif roll == 3:
			# All except one random node
			if target_nodes.size() <= 1:
				print("      → Skipped (need 2+ nodes, got %d)" % target_nodes.size())
				continue  # Need at least 2 nodes
			
			var exclude_idx = randi() % target_nodes.size()
			for i in range(target_nodes.size()):
				if i != exclude_idx:
					target_nodes[i].is_mountain = true
					target_nodes[i].set_mountain_color()
					target_nodes[i].become_mountain()
					nodes_made_mountains += 1
		
		if nodes_made_mountains > 0:
			print("      → Made %d nodes into mountains (from %d total in segment)" % [nodes_made_mountains, target_nodes.size()])
		mountains_created += nodes_made_mountains
	
	print("  Total: Created %d mountain nodes from %d border nodes across %d border segments" % [mountains_created, border_nodes.size(), border_segments.size()])

# ============================================================================
# STEP 12.55: CENTER MOUNTAIN NODES
# ============================================================================

func center_mountain_nodes():
	# Collect all mountain nodes
	var mountain_nodes: Array[MapNode2D] = []
	for node in map_nodes:
		if node.is_mountain:
			mountain_nodes.append(node)
	
	if mountain_nodes.size() == 0:
		print("  No mountain nodes to center")
		return
	
	# Iterate multiple times (3 passes)
	var iterations = 3
	
	for iteration in range(iterations):
		# Store new positions (apply all at once after calculation)
		var new_positions: Dictionary = {}
		
		# Iterate over all mountain nodes
		for mountain_node in mountain_nodes:
			# Skip if no connections
			if mountain_node.connections.size() == 0:
				continue
			
			# Calculate average position of all connected nodes
			var average_pos = Vector2.ZERO
			var connected_count = 0
			
			for connected_node in mountain_node.connections:
				var node_center = connected_node.position + (connected_node.size / 2.0)
				average_pos += node_center
				connected_count += 1
			
			if connected_count > 0:
				average_pos /= connected_count
				# Store new position (relative to node's current position)
				new_positions[mountain_node] = average_pos - (mountain_node.size / 2.0)
		
		# Apply all new positions
		for mountain_node in new_positions:
			mountain_node.position = new_positions[mountain_node]
		
		if iteration < iterations - 1:
			print("  Centering pass %d/%d complete" % [iteration + 1, iterations])
	
	print("  Centered %d mountain nodes (%d iterations)" % [mountain_nodes.size(), iterations])

# ============================================================================
# STEP 12.6: DISCONNECT MOUNTAIN NODES
# ============================================================================

func disconnect_mountain_nodes():
	var disconnected_count = 0
	
	for node in map_nodes:
		if node.is_mountain:
			# Remove all connections from this mountain node
			for neighbor in node.connections.duplicate():
				# Remove connection from both sides
				node.connections.erase(neighbor)
				neighbor.connections.erase(node)
				disconnected_count += 1
	
	print("  Disconnected %d connections from mountain nodes" % disconnected_count)
	
	# Rebuild AStar2D graph (exclude mountains)
	if astar != null:
		build_astar_graph()

# ============================================================================
# STEP 13: VISUALIZATION
# ============================================================================

func visualize_map():
	queue_redraw()

# Draws a smooth Bezier curve between two points with variation
func draw_curved_line(pos_a: Vector2, pos_b: Vector2, color: Color, width: float, node_a: MapNode2D, node_b: MapNode2D):
	var direction = (pos_b - pos_a).normalized()
	var distance = pos_a.distance_to(pos_b)
	
	# Determine curve direction to reduce crossings
	# Use a deterministic direction based on node positions
	# This creates consistent patterns that reduce crossings
	var direction_hash = hash(Vector2i(int(pos_a.x), int(pos_a.y)) + Vector2i(int(pos_b.x), int(pos_b.y)))
	var curve_dir = 1.0 if direction_hash % 2 == 0 else -1.0
	
	# For longer paths, add S-curve (double curve) with probability
	# Use deterministic hash based on nodes for consistency
	var node_hash = hash(str(node_a.node_index) + "_" + str(node_b.node_index))
	var use_s_curve = distance > s_curve_threshold and (float(node_hash % 100) / 100.0) < s_curve_probability
	
	var perpendicular = Vector2(-direction.y, direction.x) * curve_dir
	# Use deterministic curve strength based on nodes (not random, for consistency)
	var min_strength = curve_strength * 0.2
	var max_strength = curve_strength * 0.5
	var strength_hash = hash(str(node_b.node_index) + "_" + str(node_a.node_index))  # Different hash for variation
	var random_strength = min_strength + (max_strength - min_strength) * (float(strength_hash % 100) / 100.0)
	var base_offset = distance * random_strength
	
	if use_s_curve:
		# S-curve: two control points creating an S shape
		var control1 = pos_a + direction * (distance * 0.33) + perpendicular * base_offset
		var control2 = pos_a + direction * (distance * 0.67) - perpendicular * base_offset
		
		# Cubic Bezier curve (4 points: start, control1, control2, end)
		var segments = max(12, int(distance / 4.0))
		var points = PackedVector2Array()
		
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
		
		# Draw the curve as a polyline with orientation-adjusted width and color
		for i in range(points.size() - 1):
			var segment_width = get_orientation_adjusted_width(width, points[i], points[i + 1])
			var segment_color = get_orientation_adjusted_color(color, points[i], points[i + 1])
			draw_line(points[i], points[i + 1], segment_color, segment_width)
	else:
		# Single curve: one control point creating an arc
		var control_offset = perpendicular * base_offset
		var control_point = (pos_a + pos_b) / 2.0 + control_offset
		
		# Quadratic Bezier curve (3 points: start, control, end)
		var segments = max(8, int(distance / 5.0))
		var points = PackedVector2Array()
		
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			# Quadratic Bezier: (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
			var point = (1.0 - t) * (1.0 - t) * pos_a + 2.0 * (1.0 - t) * t * control_point + t * t * pos_b
			points.append(point)
		
		# Draw the curve as a polyline with orientation-adjusted width and color
		for i in range(points.size() - 1):
			var segment_width = get_orientation_adjusted_width(width, points[i], points[i + 1])
			var segment_color = get_orientation_adjusted_color(color, points[i], points[i + 1])
			draw_line(points[i], points[i + 1], segment_color, segment_width)

func _draw():
	if not is_instance_valid(self):
		return
	
	# Draw landmass fill FIRST (so it appears behind everything)
	if enable_landmass_shading and expanded_coast_lines.size() > 0:
		draw_landmass_fill()
	
	# Draw connection lines directly from node connections (don't use stored edge positions)
	var edges_drawn = 0
	var processed_edges = {}
	
	for node in map_nodes:
		for neighbor in node.connections:
			# Avoid drawing same edge twice
			var key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
			if processed_edges.has(key):
				continue
			processed_edges[key] = true
			
			# Control nodes position from top-left, so add half size for center
			var pos_a = node.position + (node.size / 2.0)
			var pos_b = neighbor.position + (neighbor.size / 2.0)
			
			# All connections use the same color (no special coastal coloring)
			# Adjust line width and color based on orientation
			var adjusted_width = get_orientation_adjusted_width(line_width, pos_a, pos_b)
			var adjusted_color = get_orientation_adjusted_color(line_color, pos_a, pos_b)
			
			if use_curved_lines:
				# Draw smooth Bezier curve with variation
				draw_curved_line(pos_a, pos_b, adjusted_color, adjusted_width, node, neighbor)
			else:
				# Draw straight line
				draw_line(pos_a, pos_b, adjusted_color, adjusted_width)
	
	# Draw coastal ripples FIRST (behind main coast line)
	if enable_coast_ripples and ripple_count > 0:
		draw_coast_ripples()
	
	# Draw player trail (completed paths)
	draw_player_trail()
	
	# Draw current travel path (in progress)
	if map_state == MapState.PARTY_MOVING and current_travel_path.size() > 1:
		draw_dotted_path(current_travel_path, trail_color, trail_line_width)
	
	# Draw hover preview path
	if hover_preview_path.size() > 1:
		draw_preview_path(hover_preview_path)
	
	# Draw expanded coast lines LAST (so they appear on top)
	for coast_line in expanded_coast_lines:
		var pos_a = coast_line[0]
		var pos_b = coast_line[1]
		
		# Adjust line width based on orientation
		var adjusted_coast_width = get_orientation_adjusted_width(coast_line_width, pos_a, pos_b)
		
		# Draw coast line with coast color
		draw_line(pos_a, pos_b, coast_line_color, adjusted_coast_width)
		
		# Draw rounded caps at endpoints
		var cap_radius = adjusted_coast_width / 2.0
		draw_circle(pos_a, cap_radius, coast_line_color)
		draw_circle(pos_b, cap_radius, coast_line_color)
		
		edges_drawn += 1
	

# ============================================================================
# COASTAL RIPPLES
# ============================================================================

func draw_coast_ripples():
	# Draw concentric ripple lines expanding outward from the coast
	# Each ripple uses the pre-calculated away_direction from coastal nodes
	
	if coastal_nodes.size() == 0 or coastal_connections.size() == 0:
		return
	
	# For each ripple layer (outermost first so inner ones draw on top)
	for ripple_index in range(ripple_count - 1, -1, -1):
		# Calculate cumulative distance for this ripple
		var cumulative_distance = coast_expansion_distance
		for i in range(ripple_index + 1):
			if i == 0:
				cumulative_distance += ripple_base_spacing
			else:
				cumulative_distance += ripple_base_spacing * pow(ripple_spacing_growth, i)
		
		# Calculate width for this ripple
		var ripple_width = ripple_base_width * pow(ripple_width_decay, ripple_index)
		
		# Calculate color for this ripple
		var color_offset = ripple_color_fade * ripple_index
		var ripple_alpha = ripple_base_color.a * pow(ripple_alpha_decay, ripple_index)
		var ripple_color = Color(
			min(ripple_base_color.r + color_offset, 1.0),
			min(ripple_base_color.g + color_offset, 1.0),
			min(ripple_base_color.b + color_offset, 1.0),
			ripple_alpha
		)
		
		# Generate expanded positions for this ripple distance
		var ripple_positions: Dictionary = {}
		for node in coastal_nodes:
			var node_center = node.position + (node.size / 2.0)
			var away_vector = Vector2(cos(node.away_direction), sin(node.away_direction))
			var ripple_pos = node_center + away_vector * cumulative_distance
			ripple_positions[node.node_index] = ripple_pos
		
		# Draw ripple lines for each coastal connection
		for connection in coastal_connections:
			var node_a = connection[0]
			var node_b = connection[1]
			
			var pos_a = ripple_positions.get(node_a.node_index)
			var pos_b = ripple_positions.get(node_b.node_index)
			
			if pos_a != null and pos_b != null:
				var adjusted_width = get_orientation_adjusted_width(ripple_width, pos_a, pos_b)
				draw_line(pos_a, pos_b, ripple_color, adjusted_width)
				
				# Rounded caps
				var cap_radius = adjusted_width / 2.0
				draw_circle(pos_a, cap_radius, ripple_color)
				draw_circle(pos_b, cap_radius, ripple_color)

# ============================================================================
# LANDMASS SHADING
# ============================================================================

func draw_landmass_fill():
	# Build a closed polygon from the expanded coastline
	var polygon_points = build_coast_polygon()
	if polygon_points.size() < 3:
		print("DEBUG: Landmass polygon has < 3 points: %d" % polygon_points.size())
		return  # Need at least 3 points for a polygon
	
	# Draw filled polygon with solid color (no gradient)
	print("DEBUG: Drawing landmass with %d points" % polygon_points.size())
	draw_colored_polygon(polygon_points, landmass_base_color)

func build_coast_polygon() -> PackedVector2Array:
	# Build a closed polygon by traversing coastal nodes in connection order
	# This is more reliable than building from line segments
	if coastal_nodes.size() == 0 or expanded_coast_lines.size() == 0:
		return PackedVector2Array()
	
	# Get expanded positions for all coastal nodes
	var expanded_positions: Dictionary = {}
	for node in coastal_nodes:
		var node_center = node.position + (node.size / 2.0)
		var away_vector = Vector2(cos(node.away_direction), sin(node.away_direction))
		var expanded_pos = node_center + away_vector * coast_expansion_distance
		expanded_positions[node.node_index] = expanded_pos
	
	# Build a graph of coastal connections
	var coastal_node_connections: Dictionary = {}  # node_index -> Array of connected coastal node indices
	for connection in coastal_connections:
		var node_a = connection[0]
		var node_b = connection[1]
		
		if not coastal_node_connections.has(node_a.node_index):
			coastal_node_connections[node_a.node_index] = []
		if not coastal_node_connections.has(node_b.node_index):
			coastal_node_connections[node_b.node_index] = []
		
		coastal_node_connections[node_a.node_index].append(node_b.node_index)
		coastal_node_connections[node_b.node_index].append(node_a.node_index)
	
	# Find starting node (one with fewest connections, likely an endpoint)
	var start_node_index: int = -1
	var min_connections = INF
	for node in coastal_nodes:
		var conn_count = coastal_node_connections.get(node.node_index, []).size()
		if conn_count > 0 and conn_count < min_connections:
			min_connections = conn_count
			start_node_index = node.node_index
	
	if start_node_index == -1:
		return PackedVector2Array()
	
	# Traverse the coastal nodes to build ordered polygon
	var polygon: PackedVector2Array = []
	var visited_edges: Dictionary = {}  # "node1_node2" -> true
	var current_node_index = start_node_index
	
	while true:
		var current_pos = expanded_positions.get(current_node_index)
		if current_pos == null:
				break
		
		polygon.append(current_pos)
		
		# Find next coastal node
		var next_node_index: int = -1
		var best_angle = -INF
		
		var candidates = coastal_node_connections.get(current_node_index, [])
		for candidate_index in candidates:
			var edge_key = "%d_%d" % [min(current_node_index, candidate_index), max(current_node_index, candidate_index)]
			if visited_edges.has(edge_key):
				continue
		
			# Calculate turn direction (if we have a previous point)
			if polygon.size() >= 2:
				var prev_pos = polygon[polygon.size() - 2]
				var current_pos_vec = polygon[polygon.size() - 1]
				var candidate_pos = expanded_positions.get(candidate_index)
				if candidate_pos == null:
					continue
				
				var dir_prev = (current_pos_vec - prev_pos).normalized()
				var dir_next = (candidate_pos - current_pos_vec).normalized()
				
				# Cross product to determine turn direction (positive = counter-clockwise)
				var cross = dir_prev.x * dir_next.y - dir_prev.y * dir_next.x
				if cross > best_angle:
					best_angle = cross
					next_node_index = candidate_index
			else:
				# First step: pick any connection
				next_node_index = candidate_index
				break
		
		if next_node_index == -1:
			break  # No more connections
		
		# Mark edge as visited
		var edge_key = "%d_%d" % [min(current_node_index, next_node_index), max(current_node_index, next_node_index)]
		visited_edges[edge_key] = true
		current_node_index = next_node_index
		
		# Stop if we've looped back to start
		if polygon.size() > 2 and current_node_index == start_node_index:
			break
		
		# Safety: prevent infinite loops
		if polygon.size() > coastal_nodes.size() * 2:
			break
	
	# Ensure polygon is closed
	if polygon.size() > 2:
		if polygon[0].distance_to(polygon[polygon.size() - 1]) > 1.0:
			polygon.append(polygon[0])
	
	return polygon

func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	# Calculate shortest distance from point to line segment
	var line_vec = line_end - line_start
	var line_len_sq = line_vec.length_squared()
	
	if line_len_sq < 0.0001:
		# Line is actually a point
		return point.distance_to(line_start)
	
	var t = clamp((point - line_start).dot(line_vec) / line_len_sq, 0.0, 1.0)
	var closest_point = line_start + t * line_vec
	return point.distance_to(closest_point)

# ============================================================================
# LINE WIDTH ORIENTATION HELPER
# ============================================================================

func get_orientation_adjusted_width(base_width: float, pos_a: Vector2, pos_b: Vector2) -> float:
	# Calculate line orientation (0 = horizontal, PI/2 = vertical)
	var direction = (pos_b - pos_a).normalized()
	var angle = abs(atan2(direction.y, direction.x))
	
	# Normalize to 0-PI/2 range (0 = horizontal, PI/2 = vertical)
	if angle > PI / 2.0:
		angle = PI - angle
	
	# Calculate how horizontal the line is (0.0 = vertical, 1.0 = horizontal)
	var horizontalness = cos(angle)
	
	# Interpolate width: vertical (1.0x) to horizontal (multiplier x)
	var adjusted_width = base_width * (1.0 + (horizontal_line_width_multiplier - 1.0) * horizontalness)
	
	return adjusted_width

func get_orientation_adjusted_color(base_color: Color, pos_a: Vector2, pos_b: Vector2) -> Color:
	# Calculate line orientation (0 = horizontal, PI/2 = vertical)
	var direction = (pos_b - pos_a).normalized()
	var angle = abs(atan2(direction.y, direction.x))
	
	# Normalize to 0-PI/2 range (0 = horizontal, PI/2 = vertical)
	if angle > PI / 2.0:
		angle = PI - angle
	
	# Calculate how horizontal the line is (0.0 = vertical, 1.0 = horizontal)
	var horizontalness = cos(angle)
	
	# Darken color based on horizontalness (subtle amount)
	var darken_factor = horizontal_line_darken * horizontalness
	var adjusted_color = base_color
	adjusted_color.r *= (1.0 - darken_factor)
	adjusted_color.g *= (1.0 - darken_factor)
	adjusted_color.b *= (1.0 - darken_factor)
	
	return adjusted_color

# ============================================================================
# PLAYER TRAIL DRAWING
# ============================================================================

## Get edge key for visited paths dictionary
func _get_edge_key(node_a: MapNode2D, node_b: MapNode2D) -> String:
	return str(min(node_a.node_index, node_b.node_index)) + "_" + str(max(node_a.node_index, node_b.node_index))

## Draw all completed player trail paths
func draw_player_trail():
	# Draw dotted lines for all visited paths
	for edge_key in visited_paths:
		var path_points = visited_paths[edge_key]
		if path_points is PackedVector2Array and path_points.size() > 1:
			draw_dotted_path(path_points, trail_color, trail_line_width)

## Draw a dotted line along a path
func draw_dotted_path(path_points: PackedVector2Array, color: Color, width: float):
	if path_points.size() < 2:
		return
	
	# Use fixed width for trail (no orientation adjustment) to ensure consistent dot appearance
	var fixed_width = width
	
	# Calculate total path length and segment lengths
	var total_path_length = 0.0
	var segment_lengths: Array[float] = []
	for i in range(path_points.size() - 1):
		var segment_length = path_points[i].distance_to(path_points[i + 1])
		segment_lengths.append(segment_length)
		total_path_length += segment_length
	
	if total_path_length <= 0.0:
		return
	
	# Apply consistent dot pattern along the entire path (not per segment)
	# Pattern repeats: dot_length, gap, dot_length, gap...
	# Add small variations for organic feel while maintaining base pattern
	var base_dot_pattern_length = trail_dot_length + trail_dot_gap
	var distance_along_path = 0.0
	var dot_index = 0  # Track dot index for deterministic variation
	
	while distance_along_path < total_path_length:
		# Use base pattern to determine position (keeps consistency)
		var pattern_offset = fmod(distance_along_path, base_dot_pattern_length)
		var in_dot = pattern_offset < trail_dot_length
		
		if in_dot:
			# We're drawing a dot (as a circle)
			# Calculate center of dot
			var dot_center_distance = distance_along_path + (trail_dot_length * 0.5)
			dot_center_distance = clamp(dot_center_distance, 0.0, total_path_length)
			
			# Get center position of the dot
			var dot_center_pos = _get_position_at_path_distance(path_points, segment_lengths, dot_center_distance)
			
			# Calculate local path direction for orientation adjustment
			# Sample points before and after to get direction
			var sample_offset = 2.0  # Small offset to sample direction
			var pos_before = _get_position_at_path_distance(path_points, segment_lengths, max(0.0, dot_center_distance - sample_offset))
			var pos_after = _get_position_at_path_distance(path_points, segment_lengths, min(total_path_length, dot_center_distance + sample_offset))
			var local_direction = (pos_after - pos_before).normalized()
			
			# Calculate orientation adjustment (same logic as connection lines)
			var angle = abs(atan2(local_direction.y, local_direction.x))
			if angle > PI / 2.0:
				angle = PI - angle
			var horizontalness = cos(angle)  # 0.0 = vertical, 1.0 = horizontal
			
			# Apply orientation scaling: more horizontal = larger radius and spacing
			# Use the same multiplier as connection lines for consistency
			var orientation_scale = 1.0 + (horizontal_line_width_multiplier - 1.0) * horizontalness
			
			# Calculate deterministic variation for this dot
			var variation_seed = hash(Vector2i(int(distance_along_path * 10.0), dot_index))
			var size_variation = (float(variation_seed % 200) / 100.0 - 1.0) * trail_dot_size_variation  # -variation to +variation
			
			# Calculate dot radius with size variation AND orientation adjustment
			var base_radius = fixed_width * 0.5
			var dot_radius = base_radius * (1.0 + size_variation) * orientation_scale
			
			# Draw outline first (slightly larger, darker)
			var outline_radius = dot_radius + trail_outline_width
			draw_circle(dot_center_pos, outline_radius, trail_outline_color)
			
			# Draw main dot circle
			draw_circle(dot_center_pos, dot_radius, color)
			
			# Advance past the dot (use base length, but will be adjusted by spacing variation)
			distance_along_path += trail_dot_length
			dot_index += 1
		else:
			# We're in a gap - apply spacing variation AND orientation adjustment
			var gap_remaining = base_dot_pattern_length - pattern_offset
			
			# Get position at gap start to calculate orientation
			var gap_start_distance = distance_along_path
			var gap_start_pos = _get_position_at_path_distance(path_points, segment_lengths, gap_start_distance)
			
			# Calculate local path direction for orientation adjustment
			var sample_offset = 2.0
			var pos_before = _get_position_at_path_distance(path_points, segment_lengths, max(0.0, gap_start_distance - sample_offset))
			var pos_after = _get_position_at_path_distance(path_points, segment_lengths, min(total_path_length, gap_start_distance + sample_offset))
			var local_direction = (pos_after - pos_before).normalized()
			
			# Calculate orientation adjustment
			var angle = abs(atan2(local_direction.y, local_direction.x))
			if angle > PI / 2.0:
				angle = PI - angle
			var horizontalness = cos(angle)
			var orientation_scale = 1.0 + (horizontal_line_width_multiplier - 1.0) * horizontalness
			
			# Add small spacing variation to this gap (deterministic)
			var spacing_seed = hash(Vector2i(int(distance_along_path * 7.0), dot_index))
			var spacing_variation = (float(spacing_seed % 200) / 100.0 - 1.0) * trail_dot_spacing_variation
			
			# Apply both spacing variation AND orientation adjustment
			var adjusted_gap = gap_remaining * (1.0 + spacing_variation) * orientation_scale
			
			distance_along_path = min(distance_along_path + adjusted_gap, total_path_length)

## Draw preview path by highlighting connection lines (hover preview)
func draw_preview_path(path_points: PackedVector2Array):
	if path_points.size() < 2:
		return
	
	# Draw the path as a continuous line
	# Path points are already curved from get_path_points(), so just draw them
	for i in range(path_points.size() - 1):
		var pos_a = path_points[i]
		var pos_b = path_points[i + 1]
		
		# Apply orientation adjustment like connection lines
		var adjusted_width = get_orientation_adjusted_width(line_width, pos_a, pos_b)
		var adjusted_color = get_orientation_adjusted_color(preview_path_color, pos_a, pos_b)
		draw_line(pos_a, pos_b, adjusted_color, adjusted_width)

## Helper: Get position at a specific distance along the path
func _get_position_at_path_distance(path_points: PackedVector2Array, segment_lengths: Array[float], target_distance: float) -> Vector2:
	if path_points.size() < 2:
		return path_points[0] if path_points.size() > 0 else Vector2.ZERO
	
	var accumulated_length = 0.0
	for i in range(path_points.size() - 1):
		var segment_length = segment_lengths[i]
		
		if accumulated_length + segment_length >= target_distance:
			# Target is in this segment
			var segment_remaining = target_distance - accumulated_length
			var segment_progress = segment_remaining / segment_length
			return path_points[i].lerp(path_points[i + 1], segment_progress)
		
		accumulated_length += segment_length
	
	# Past end of path
	return path_points[path_points.size() - 1]

# ============================================================================
# UTILITY
# ============================================================================

func get_node_at_position(pos: Vector2, max_distance: float = 10.0) -> MapNode2D:
	var closest: MapNode2D = null
	var closest_dist = max_distance
	
	for node in map_nodes:
		var dist = node.position.distance_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = node
	
	return closest


func regenerate_map() -> void:
	clear_existing_nodes()
	generate_map()

func spawn_party():
	# Spawn the party at a random node after map generation completes
	if not party_indicator:
		push_warning("MapGenerator2D: party_indicator not assigned. Party will not spawn.")
		return
	
	if map_nodes.size() == 0:
		push_error("MapGenerator2D: Cannot spawn party - no map nodes available")
		return
	
	# Filter out mountain nodes (party can't spawn on mountains)
	var valid_nodes: Array[MapNode2D] = []
	for node in map_nodes:
		if not node.is_mountain:
			valid_nodes.append(node)
	
	if valid_nodes.size() == 0:
		push_error("MapGenerator2D: No valid nodes to spawn party (all are mountains?)")
		return
	
	# Pick a random valid node
	var spawn_node = valid_nodes[randi() % valid_nodes.size()]
	set_party_position(spawn_node)
	
	print("Party spawned at node %d" % spawn_node.node_index)

# ============================================================================
# PARTY MANAGEMENT
# ============================================================================

## Set party position immediately (no animation)
func set_party_position(node: MapNode2D):
	if not party_indicator or not node:
		return
	
	current_party_node = node
	var node_center = node.position + (node.size / 2.0)
	party_indicator.global_position = node_center

## Check if party can move to a node (must be connected to current node)
func can_party_move_to(node: MapNode2D) -> bool:
	if not current_party_node:
		return false
	
	if not node:
		return false
	
	# Can't move to mountains
	if node.is_mountain:
		return false
	
	# Can't move while already traveling
	if map_state == MapState.PARTY_MOVING:
		return false
	
	# Must be connected to current node
	return current_party_node.is_connected_to(node)

## Get all nodes the party can move to from current position
func get_party_available_moves() -> Array[MapNode2D]:
	if not current_party_node:
		return []
	
	var available: Array[MapNode2D] = []
	for neighbor in current_party_node.connections:
		if not neighbor.is_mountain:
			available.append(neighbor)
	
	return available

## Calculate path points along a curve between two nodes
func get_path_points(node_a: MapNode2D, node_b: MapNode2D) -> PackedVector2Array:
	# CRITICAL: Normalize node order to match connection drawing order
	# Connection drawing uses processed_edges which normalizes by min/max node_index
	# So we need to always use the same order (lower index first) to match the drawn curve
	var first_node = node_a if node_a.node_index < node_b.node_index else node_b
	var second_node = node_b if node_a.node_index < node_b.node_index else node_a
	
	var pos_a = first_node.position + (first_node.size / 2.0)
	var pos_b = second_node.position + (second_node.size / 2.0)
	var direction = (pos_b - pos_a).normalized()
	var distance = pos_a.distance_to(pos_b)
	
	# Determine curve direction (consistent with draw_curved_line)
	var direction_hash = hash(Vector2i(int(pos_a.x), int(pos_a.y)) + Vector2i(int(pos_b.x), int(pos_b.y)))
	var curve_dir = 1.0 if direction_hash % 2 == 0 else -1.0
	
	# Check if we should use S-curve (same logic as drawing)
	# Use deterministic hash based on nodes for consistency (same as draw_curved_line)
	var node_hash = hash(str(first_node.node_index) + "_" + str(second_node.node_index))
	var use_s_curve = distance > s_curve_threshold and (float(node_hash % 100) / 100.0) < s_curve_probability
	
	var perpendicular = Vector2(-direction.y, direction.x) * curve_dir
	# Use deterministic curve strength based on nodes (not random, for consistency)
	var min_strength = curve_strength * 0.2
	var max_strength = curve_strength * 0.5
	var strength_hash = hash(str(second_node.node_index) + "_" + str(first_node.node_index))  # Different hash for variation
	var random_strength = min_strength + (max_strength - min_strength) * (float(strength_hash % 100) / 100.0)
	var base_offset = distance * random_strength
	
	var points = PackedVector2Array()
	
	if use_s_curve and use_curved_lines:
		# S-curve: cubic Bezier
		var control1 = pos_a + direction * (distance * 0.33) + perpendicular * base_offset
		var control2 = pos_a + direction * (distance * 0.67) - perpendicular * base_offset
		
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
	elif use_curved_lines:
		# Single curve: quadratic Bezier
		var control_offset = perpendicular * base_offset
		var control = (pos_a + pos_b) / 2.0 + control_offset
		
		var segments = max(8, int(distance / 5.0))
		
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			var mt = 1.0 - t
			
			# Quadratic Bezier: (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
			var point = mt * mt * pos_a + 2.0 * mt * t * control + t * t * pos_b
			points.append(point)
	else:
		# Straight line
		points.append(pos_a)
		points.append(pos_b)
	
	# If actual travel direction is opposite to normalized order, reverse the path
	# (We normalized to lower-index first for curve calculation, but travel might be in reverse)
	if node_a.node_index > node_b.node_index:
		# Reverse the points array
		var reversed_points = PackedVector2Array()
		for i in range(points.size() - 1, -1, -1):
			reversed_points.append(points[i])
		return reversed_points
	
	return points

## Navigate party to a neighboring node along the curved path
## Sets up travel state - _process() handles the actual movement
func navigate_party_to_node(target_node: MapNode2D):
	if not can_party_move_to(target_node):
		push_warning("MapGenerator2D: Cannot navigate party to node %d" % target_node.node_index)
		return
	
	if not party_indicator:
		push_error("MapGenerator2D: party_indicator not assigned")
		return
	
	var from_node = current_party_node
	var path_points = get_path_points(from_node, target_node)
	
	if path_points.size() < 2:
		# Fallback: just jump to target
		set_party_position(target_node)
		return
	
	# Calculate total distance along path
	var total_distance = 0.0
	for i in range(path_points.size() - 1):
		total_distance += path_points[i].distance_to(path_points[i + 1])
	
	# Clear hover preview when starting travel
	_clear_hover_preview()
	
	# Set up travel state
	map_state = MapState.PARTY_MOVING
	travel_path_points = path_points
	travel_target_node = target_node
	travel_start_node = from_node
	travel_total_distance = total_distance
	travel_elapsed_distance = 0.0
	travel_wait_timer = 0.0
	
	# Initialize current travel path with starting point
	current_travel_path.clear()
	current_travel_path.append(travel_path_points[0])
	
	# Request redraw to show trail
	queue_redraw()
	
	print("Party started traveling to node %d" % target_node.node_index)

## Process party movement when in PARTY_MOVING state
func _process(delta: float):
	if map_state == MapState.PARTY_MOVING:
		_process_party_movement(delta)

func _input(event: InputEvent):
	# Handle mouse wheel for path cycling when hovering
	# This takes priority over zoom when a node is hovered
	if hovered_node:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				# Cycle to next path (only if multiple paths exist)
				if hover_alternative_paths.size() > 1:
					hover_current_path_index = (hover_current_path_index + 1) % hover_alternative_paths.size()
					_update_hover_preview_path()
					queue_redraw()
				# Mark event as handled to prevent zoom
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				# Cycle to previous path (only if multiple paths exist)
				if hover_alternative_paths.size() > 1:
					hover_current_path_index = (hover_current_path_index - 1 + hover_alternative_paths.size()) % hover_alternative_paths.size()
					_update_hover_preview_path()
					queue_redraw()
				# Mark event as handled to prevent zoom
				get_viewport().set_input_as_handled()

## Handle party movement along path
func _process_party_movement(delta: float):
	if travel_path_points.size() < 2:
		# Invalid path, jump to target
		_finish_party_travel()
		return
	
	# Check if we're in wait phase (arrived at destination)
	if travel_wait_timer > 0.0:
		travel_wait_timer -= delta
		if travel_wait_timer <= 0.0:
			# Wait complete, return to idle
			_finish_party_travel()
		return
	
	# Move along path
	var distance_this_frame = party_travel_speed * delta
	travel_elapsed_distance += distance_this_frame
	
	if travel_elapsed_distance >= travel_total_distance:
		# Reached destination
		set_party_position(travel_target_node)
		travel_wait_timer = party_wait_at_node
		return
	
	# Calculate current position along path
	var target_distance = travel_elapsed_distance
	var accumulated_distance = 0.0
	var current_pos = travel_path_points[0]
	
	for i in range(travel_path_points.size() - 1):
		var segment_distance = travel_path_points[i].distance_to(travel_path_points[i + 1])
		if accumulated_distance + segment_distance >= target_distance:
			# We're in this segment
			var segment_progress = (target_distance - accumulated_distance) / segment_distance
			current_pos = travel_path_points[i].lerp(travel_path_points[i + 1], segment_progress)
			break
		accumulated_distance += segment_distance
		current_pos = travel_path_points[i + 1]
	
	# Update party indicator position
	party_indicator.global_position = current_pos
	
	# Update current travel path - add current position to the path being drawn
	# Build path from start to current position
	current_travel_path.clear()
	current_travel_path.append(travel_path_points[0])  # Start position
	
	# Reuse accumulated_distance variable, reset for path building
	accumulated_distance = 0.0
	for i in range(travel_path_points.size() - 1):
		var segment_distance = travel_path_points[i].distance_to(travel_path_points[i + 1])
		if accumulated_distance + segment_distance <= travel_elapsed_distance:
			# Include full segment
			current_travel_path.append(travel_path_points[i + 1])
			accumulated_distance += segment_distance
		else:
			# Include partial segment up to current position
			var remaining = travel_elapsed_distance - accumulated_distance
			var segment_progress = remaining / segment_distance
			var partial_point = travel_path_points[i].lerp(travel_path_points[i + 1], segment_progress)
			current_travel_path.append(partial_point)
			break
	
	# Request redraw to update trail
	queue_redraw()

## Finish party travel and return to idle state
func _finish_party_travel():
	# Ensure we're exactly at the target
	if travel_target_node and travel_start_node:
		set_party_position(travel_target_node)
		
		# Lock in completed path - store the actual path points that were used
		var edge_key = _get_edge_key(travel_start_node, travel_target_node)
		# Store the full path points (not recalculated, use what was actually traveled)
		visited_paths[edge_key] = travel_path_points.duplicate()
		
		# Clear current travel path
		current_travel_path.clear()
		
		print("Party moved to node %d" % travel_target_node.node_index)
	
	# Clear travel state
	travel_path_points.clear()
	travel_target_node = null
	travel_start_node = null
	travel_total_distance = 0.0
	travel_elapsed_distance = 0.0
	travel_wait_timer = 0.0
	
	# Request redraw
	queue_redraw()
	
	# Return to idle state
	map_state = MapState.IDLE

## Handle node click for navigation during gameplay
func handle_node_navigation(clicked_node: MapNode2D):
	if map_state == MapState.PARTY_MOVING:
		print("Party is already traveling, ignoring click")
		return
	
	if not current_party_node:
		print("Party not spawned yet, ignoring click")
		return
	
	# Check if this is a valid move
	if can_party_move_to(clicked_node):
		navigate_party_to_node(clicked_node)
	else:
		print("Cannot move to node %d (not connected or invalid)" % clicked_node.node_index)

func _handle_generation_error(message: String):
	push_error(message)
	if auto_regenerate_on_error:
		print("  → Auto-regeneration enabled, will regenerate map after current generation completes")
		_regeneration_requested = true

# ============================================================================
# DEBUG: NODE CLICK HANDLER
# ============================================================================

func _on_node_clicked(node: MapNode2D):
	# Ignore clicks when events are paused
	if events_paused:
		return
	
	# Handle navigation
	handle_node_navigation(node)
	
	# Debug output (can be disabled later if needed)
	debug_node_away_directions(node)
	debug_node_edges(node)

func _on_node_hovered(node: MapNode2D):
	# Ignore hover when events are paused
	if events_paused:
		return
	
	# Only show hover preview when party is idle (preparing to travel)
	if map_state != MapState.IDLE:
		return
	
	hovered_node = node
	hover_current_path_index = 0
	_find_all_equal_length_paths()
	_update_hover_preview_path()
	queue_redraw()

func _on_node_hover_ended(node: MapNode2D):
	if hovered_node == node:
		_clear_hover_preview()

## Clear hover preview (called when travel starts or hover ends)
func _clear_hover_preview():
	hovered_node = null
	hover_preview_path.clear()
	hover_alternative_paths.clear()
	hover_current_path_index = 0
	queue_redraw()

func _find_all_equal_length_paths():
	hover_alternative_paths.clear()
	
	if not hovered_node or not current_party_node or not astar:
		return
	
	# Can't preview path to current node
	if hovered_node == current_party_node:
		return
	
	# Get shortest path length first
	var shortest_path_packed = astar.get_id_path(current_party_node.node_index, hovered_node.node_index)
	if shortest_path_packed.size() < 2:
		return  # No valid path
	
	# Convert PackedInt64Array to Array
	var shortest_path: Array = []
	for id in shortest_path_packed:
		shortest_path.append(id)
	
	var target_length = shortest_path.size() - 1  # Number of edges (path length in hops)
	
	# Performance optimization: For long paths, limit search or use simpler method
	var max_search_hops = 8  # Only do full BFS search for paths up to 8 hops
	var max_paths_to_find = 25  # Limit total paths found (increased for more options)
	
	if target_length > max_search_hops:
		# For long paths, just use the shortest path and find a few alternatives
		# by temporarily blocking edges from the shortest path
		var all_paths: Array[Array] = [shortest_path]  # Always include shortest
		
		# Try to find alternative paths by blocking edges from the shortest path
		# Block more edges for longer paths to find more alternatives
		var edges_to_try = min(shortest_path.size() - 1, max(5, target_length / 2))  # Try blocking up to half the edges, or 5 minimum
		for edge_idx in range(edges_to_try):
			var blocked_node_a_id = shortest_path[edge_idx]
			var blocked_node_b_id = shortest_path[edge_idx + 1]
			
			# Temporarily disconnect this edge in AStar
			var was_connected = astar.are_points_connected(blocked_node_a_id, blocked_node_b_id)
			if was_connected:
				astar.disconnect_points(blocked_node_a_id, blocked_node_b_id)
			
			# Try to find alternative path
			var alt_path_packed = astar.get_id_path(current_party_node.node_index, hovered_node.node_index)
			if alt_path_packed.size() > 0 and alt_path_packed.size() - 1 == target_length:
				# Convert PackedInt64Array to Array
				var alt_path: Array = []
				for id in alt_path_packed:
					alt_path.append(id)
				
				# Check if it's different from paths we already have
				var is_duplicate = false
				for existing_path in all_paths:
					if existing_path == alt_path:
						is_duplicate = true
						break
				
				if not is_duplicate and all_paths.size() < max_paths_to_find:
					all_paths.append(alt_path)
			
			# Reconnect the edge
			if was_connected:
				astar.connect_points(blocked_node_a_id, blocked_node_b_id)
			
			if all_paths.size() >= max_paths_to_find:
				break
		
		# Store paths (will be sorted by distance later)
		hover_alternative_paths = all_paths
		return
	
	# For shorter paths, use BFS but with better limits
	var all_paths: Array[Array] = []
	var queue: Array = []  # [current_node_index, path_so_far, visited_set]
	var start_path: Array = [current_party_node.node_index]
	var start_visited: Dictionary = {}
	start_visited[current_party_node.node_index] = true
	queue.append([current_party_node.node_index, start_path, start_visited])
	
	var max_queue_size = 2000  # Limit queue size to prevent explosion (increased for more thorough search)
	var paths_found = 0
	
	while queue.size() > 0 and paths_found < max_paths_to_find and queue.size() < max_queue_size:
		var current = queue.pop_front()
		var current_node_id = current[0]
		var path_so_far = current[1]
		var visited = current[2]
		
		# Check if we've reached the target
		if current_node_id == hovered_node.node_index:
			if path_so_far.size() - 1 == target_length:  # Same number of hops
				all_paths.append(path_so_far.duplicate())
				paths_found += 1
			continue
		
		# Don't continue if path is already too long
		if path_so_far.size() - 1 >= target_length:
			continue
		
		# Explore neighbors
		var current_node: MapNode2D = null
		for node in map_nodes:
			if node.node_index == current_node_id:
				current_node = node
				break
		
		if not current_node:
			continue
		
		for neighbor in current_node.connections:
			if neighbor.is_mountain:
				continue  # Skip mountains
			
			if visited.has(neighbor.node_index):
				continue  # Already visited in this path
			
			# Create new path state
			var new_path = path_so_far.duplicate()
			new_path.append(neighbor.node_index)
			var new_visited = visited.duplicate()
			new_visited[neighbor.node_index] = true
			
			queue.append([neighbor.node_index, new_path, new_visited])
	
	# Calculate total distance for each path and sort by distance
	var paths_with_distances: Array = []  # Array of [path, total_distance]
	
	for path in all_paths:
		var total_distance = 0.0
		# Calculate total distance by summing distances between consecutive nodes
		for i in range(path.size() - 1):
			var node_a_id = path[i]
			var node_b_id = path[i + 1]
			
			# Find the actual nodes
			var node_a: MapNode2D = null
			var node_b: MapNode2D = null
			for node in map_nodes:
				if node.node_index == node_a_id:
					node_a = node
				if node.node_index == node_b_id:
					node_b = node
				if node_a and node_b:
					break
			
			if node_a and node_b:
				var pos_a = node_a.position + (node_a.size / 2.0)
				var pos_b = node_b.position + (node_b.size / 2.0)
				total_distance += pos_a.distance_to(pos_b)
		
		paths_with_distances.append([path, total_distance])
	
	# Sort by total distance (shortest first)
	paths_with_distances.sort_custom(func(a, b): return a[1] < b[1])
	
	# Extract sorted paths
	hover_alternative_paths.clear()
	for item in paths_with_distances:
		hover_alternative_paths.append(item[0])
	
	if hover_alternative_paths.size() == 0:
		# Fallback: use the shortest path (already converted to Array)
		hover_alternative_paths.append(shortest_path)
	
	# Reset to first path (which is now the shortest distance)
	hover_current_path_index = 0

func _update_hover_preview_path():
	hover_preview_path.clear()
	
	if not hovered_node or not current_party_node or hover_alternative_paths.size() == 0:
		return
	
	# Get the currently selected path
	if hover_current_path_index < 0 or hover_current_path_index >= hover_alternative_paths.size():
		hover_current_path_index = 0
	
	var path_ids = hover_alternative_paths[hover_current_path_index]
	
	if path_ids.size() < 2:
		return  # No valid path
	
	# Convert path IDs to nodes
	var path_nodes: Array[MapNode2D] = []
	for id in path_ids:
		for node in map_nodes:
			if node.node_index == id:
				path_nodes.append(node)
				break
	
	if path_nodes.size() < 2:
		return  # Invalid path
	
	# Convert path to visual points using curved paths between each pair
	var all_path_points = PackedVector2Array()
	
	for i in range(path_nodes.size() - 1):
		var node_a = path_nodes[i]
		var node_b = path_nodes[i + 1]
		var segment_points = get_path_points(node_a, node_b)
		
		# Add segment points (skip first point if not first segment to avoid duplicates)
		if i == 0:
			all_path_points.append_array(segment_points)
		else:
			# Skip first point to avoid duplicate
			for j in range(1, segment_points.size()):
				all_path_points.append(segment_points[j])
	
	hover_preview_path = all_path_points

func debug_node_away_directions(node: MapNode2D):
	print("\n=== DEBUG: Node %d Away Direction Analysis ===" % node.node_index)
	print("Node %d: is_coastal=%s, connections=%d" % [node.node_index, node.is_coastal, node.connections.size()])
	
	var away_deg = rad_to_deg(node.away_direction) if node.away_direction != 0.0 else 0.0
	var away_str = "%.1f° (%.4f rad)" % [away_deg, node.away_direction] if node.away_direction != 0.0 else "NOT SET (0.0)"
	print("  Node %d away_direction: %s" % [node.node_index, away_str])
	
	if node.is_coastal:
		var node_center = node.position + (node.size / 2.0)
		var away_vec = Vector2(cos(node.away_direction), sin(node.away_direction))
		var expanded_pos = node_center + away_vec * coast_expansion_distance
		print("  Node %d center: (%.1f, %.1f)" % [node.node_index, node_center.x, node_center.y])
		print("  Node %d away_vector: (%.3f, %.3f)" % [node.node_index, away_vec.x, away_vec.y])
		print("  Node %d expanded_pos: (%.1f, %.1f)" % [node.node_index, expanded_pos.x, expanded_pos.y])
	
	# Analyze which neighbors were used for away_direction calculation
	if node.is_coastal and node.connections.size() >= 3:
		var coastal_neighbors: Array[MapNode2D] = []
		var non_coastal_neighbors: Array[MapNode2D] = []
		
		for neighbor in node.connections:
			if neighbor.is_coastal:
				coastal_neighbors.append(neighbor)
			else:
				non_coastal_neighbors.append(neighbor)
		
		if coastal_neighbors.size() >= 3:
			print("  PASS 1 LOGIC ANALYSIS (3+ coastal neighbors):")
			# Find which neighbors have coastal edges
			var coastal_neighbors_with_coastal_edges: Array[MapNode2D] = []
			for neighbor in coastal_neighbors:
				var edge_is_coastal = false
				for connection in coastal_connections:
					if (connection[0] == node and connection[1] == neighbor) or (connection[0] == neighbor and connection[1] == node):
						edge_is_coastal = true
						break
				
				if edge_is_coastal:
					coastal_neighbors_with_coastal_edges.append(neighbor)
			
			print("    Total coastal neighbors: %d" % coastal_neighbors.size())
			print("    Coastal neighbors WITH coastal edges: %d" % coastal_neighbors_with_coastal_edges.size())
			
			if coastal_neighbors_with_coastal_edges.size() == 2:
				var used_1 = coastal_neighbors_with_coastal_edges[0]
				var used_2 = coastal_neighbors_with_coastal_edges[1]
				print("    ✓ USED FOR ARC: Neighbors %d and %d" % [used_1.node_index, used_2.node_index])
				
				# Calculate what the arc would be
				var node_center = node.position + (node.size / 2.0)
				var pos_1 = used_1.position + (used_1.size / 2.0)
				var pos_2 = used_2.position + (used_2.size / 2.0)
				var vec_1 = (pos_1 - node_center).normalized()
				var vec_2 = (pos_2 - node_center).normalized()
				var angle_1 = atan2(vec_1.y, vec_1.x)
				var angle_2 = atan2(vec_2.y, vec_2.x)
				if angle_1 < 0:
					angle_1 += TAU
				if angle_2 < 0:
					angle_2 += TAU
				var arc_1_start = min(angle_1, angle_2)
				var arc_1_end = max(angle_1, angle_2)
				var arc_1_span = arc_1_end - arc_1_start
				var arc_2_span = TAU - arc_1_span
				print("    Arc 1: %.1f° to %.1f° (span=%.1f°)" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end), rad_to_deg(arc_1_span)])
				print("    Arc 2: %.1f° to %.1f° (span=%.1f°)" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU), rad_to_deg(arc_2_span)])
			else:
				print("    ✗ ERROR: Expected 2 coastal neighbors with coastal edges, got %d" % coastal_neighbors_with_coastal_edges.size())
				if coastal_neighbors_with_coastal_edges.size() > 0:
					print("    Would have used: %s" % str(coastal_neighbors_with_coastal_edges.map(func(n): return n.node_index)))
	
	print("  All Neighbors:")
	for neighbor in node.connections:
		var neighbor_away_deg = rad_to_deg(neighbor.away_direction) if neighbor.away_direction != 0.0 else 0.0
		var neighbor_away_str = "%.1f° (%.4f rad)" % [neighbor_away_deg, neighbor.away_direction] if neighbor.away_direction != 0.0 else "NOT SET (0.0)"
		var neighbor_center = neighbor.position + (neighbor.size / 2.0)
		var vec_to_neighbor = (neighbor_center - (node.position + (node.size / 2.0))).normalized()
		var angle_to_neighbor = atan2(vec_to_neighbor.y, vec_to_neighbor.x)
		if angle_to_neighbor < 0:
			angle_to_neighbor += TAU
		var angle_to_neighbor_deg = rad_to_deg(angle_to_neighbor)
		
		# Check if edge is coastal
		var edge_is_coastal = false
		for connection in coastal_connections:
			if (connection[0] == node and connection[1] == neighbor) or (connection[0] == neighbor and connection[1] == node):
				edge_is_coastal = true
				break
		
		var edge_status = "COASTAL EDGE" if edge_is_coastal else "interior edge"
		print("    Neighbor %d: is_coastal=%s, %s, away_direction=%s, angle_to_neighbor=%.1f°" % [neighbor.node_index, neighbor.is_coastal, edge_status, neighbor_away_str, angle_to_neighbor_deg])
		
		if neighbor.is_coastal and neighbor.away_direction != 0.0:
			var neighbor_away_vec = Vector2(cos(neighbor.away_direction), sin(neighbor.away_direction))
			var neighbor_expanded_pos = neighbor_center + neighbor_away_vec * coast_expansion_distance
			print("      Neighbor %d center: (%.1f, %.1f)" % [neighbor.node_index, neighbor_center.x, neighbor_center.y])
			print("      Neighbor %d away_vector: (%.3f, %.3f)" % [neighbor.node_index, neighbor_away_vec.x, neighbor_away_vec.y])
			print("      Neighbor %d expanded_pos: (%.1f, %.1f)" % [neighbor.node_index, neighbor_expanded_pos.x, neighbor_expanded_pos.y])
	
	print("=== End Away Direction Debug ===\n")

func debug_node_edges(node: MapNode2D):
	print("\n=== DEBUG: Node %d Edge Analysis ===" % node.node_index)
	print("Node %d is currently marked as coastal: %s" % [node.node_index, node.is_coastal])
	print("Node %d has %d connections" % [node.node_index, node.connections.size()])
	print("")
	
	# Analyze each edge connected to this node
	for neighbor in node.connections:
		var edge_key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
		
		# Count triangles containing this edge (DETAILED)
		var triangle_count = 0
		var triangle_nodes: Array = []
		var all_candidates: Array = []  # All nodes checked
		
		print("  Edge %d-%d: Checking for triangles..." % [node.node_index, neighbor.node_index])
		for node_c in node.connections:
			if node_c == neighbor:
				continue
			all_candidates.append(node_c.node_index)
			# Check if node_c is also connected to neighbor (forms triangle)
			var is_connected_to_neighbor = node_c in neighbor.connections
			print("    Checking node %d: connected to neighbor? %s" % [node_c.node_index, is_connected_to_neighbor])
			if is_connected_to_neighbor:
				triangle_count += 1
				triangle_nodes.append(node_c.node_index)
				print("      -> Triangle found: %d-%d-%d" % [node.node_index, neighbor.node_index, node_c.node_index])
				if triangle_count >= 2:
					print("      -> Reached 2 triangles, stopping")
					break  # Interior edges have exactly 2 triangles
		
		print("    All candidates checked: %s" % str(all_candidates))
		
		# Determine if this is a boundary edge
		var is_boundary_edge = triangle_count < 2
		var edge_type = "BOUNDARY" if is_boundary_edge else "INTERIOR"
		
		print("  Edge %d-%d:" % [node.node_index, neighbor.node_index])
		print("    Neighbor %d is coastal: %s" % [neighbor.node_index, neighbor.is_coastal])
		print("    Triangle count: %d" % triangle_count)
		if triangle_count > 0:
			print("    Triangles: %s" % str(triangle_nodes))
		print("    Edge type: %s (triangle_count < 2 = %s)" % [edge_type, is_boundary_edge])
		
		# Check if this edge is in coastal_connections
		var in_coastal_connections = false
		for conn in coastal_connections:
			if (conn[0] == node and conn[1] == neighbor) or (conn[0] == neighbor and conn[1] == node):
				in_coastal_connections = true
				break
		print("    In coastal_connections: %s" % in_coastal_connections)
		print("")
	
	# Summary
	var boundary_edge_count = 0
	var coastal_neighbor_count = 0
	var non_coastal_neighbor_count = 0
	
	for neighbor in node.connections:
		if neighbor.is_coastal:
			coastal_neighbor_count += 1
		else:
			non_coastal_neighbor_count += 1
		
		# Count triangles for this edge
		var triangle_count = 0
		for node_c in node.connections:
			if node_c == neighbor:
				continue
			if node_c in neighbor.connections:
				triangle_count += 1
				if triangle_count >= 2:
					break
		
		if triangle_count < 2:
			boundary_edge_count += 1
	
	print("SUMMARY:")
	print("  Boundary edges: %d" % boundary_edge_count)
	print("  Coastal neighbors: %d" % coastal_neighbor_count)
	print("  Non-coastal neighbors: %d" % non_coastal_neighbor_count)
	print("  Should be coastal: %s (has boundary edges: %d > 0)" % [boundary_edge_count > 0, boundary_edge_count])
	print("=== End Debug ===\n")
