extends Control
class_name MapGenerator2D

## Simplified 2D Map Generator
## Features: Poisson-disk sampling, Delaunay triangulation, coastal identification, POI detection, AStar2D

# ============================================================================
# EXPORTS
# ============================================================================

@export_group("Map")
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

@export_group("Colors")
@export var line_color: Color = Color(0.588, 0.482, 0.298)  # #967b4c - Connection lines
@export var road_color: Color = Color(0.4, 0.35, 0.25)  # Darker color for roads
@export var node_base_color: Color = Color(0.635, 0.518, 0.349)  # #a28459 - Node base
@export var coast_line_color: Color = Color(0.137, 0.055, 0.035)  # #230e09 - Coast outline
@export var landmass_base_color: Color = Color(0.757, 0.635, 0.467, 1.0)  # #c1a277 - Landmass fill
@export var coastal_water_color: Color = Color(0.25, 0.45, 0.7, 1.0)  # Coastal water blobs
@export var ripple_base_color: Color = Color(0.55, 0.45, 0.32, 0.8)  # Coast ripple lines
@export var mountain_color: Color = Color(0.588, 0.482, 0.298)  # #967b4c - Mountain nodes
@export var trail_color: Color = Color(0.709, 0.0, 0.0, 1.0)  # #b50000 - Player trail
@export var trail_outline_color: Color = Color(0.4, 0.0, 0.0, 1.0)  # Trail dot outline
@export var preview_path_color: Color = Color(1.0, 0.9, 0.3, 0.6)  # Hover path preview
@export var river_color: Color = Color(0.3, 0.5, 0.8, 1.0)  # Rivers

@export_group("Lines & Strokes")
@export var line_width: float = 4.0
@export var road_width_multiplier: float = 1.5  # Roads are thicker than regular paths
@export var coast_line_width: float = 0.75

@export_group("Road Extensions")
@export var coastal_extension_count: int = 2  # How many dead-end roads to extend toward coast

@export_group("Road Spawn Rates by Biome")
@export_range(0.0, 1.0) var road_spawn_rate_forest: float = 0.7  # 70% spawn rate in forests
@export_range(0.0, 1.0) var road_spawn_rate_plains: float = 1.0  # 100% spawn rate in plains
@export_range(0.0, 1.0) var road_spawn_rate_swamp: float = 0.0  # 0% spawn rate in swamps
@export_range(0.0, 1.0) var road_spawn_rate_mountain: float = 0.3  # 30% spawn rate in mountains
@export_range(0.0, 1.0) var road_spawn_rate_badlands: float = 0.5  # 50% spawn rate in badlands
@export_range(0.0, 1.0) var road_spawn_rate_ash_plains: float = 0.4  # 40% spawn rate in ash plains

@export_group("Visibility")
@export var path_visibility_range: int = 0  # How many steps away from party to show paths (0 = only adjacent, 1 = adjacent + their neighbors, etc.)

@export var coast_expansion_distance: float = 20.0  # Base/average expansion distance (deprecated if using min/max)
@export var coast_expansion_min: float = 10.0  # Minimum coast expansion distance
@export var coast_expansion_max: float = 30.0  # Maximum coast expansion distance
@export var coast_expansion_noise_scale: float = 0.002  # Lower = smoother transitions, Higher = more variation
@export var horizontal_line_width_multiplier: float = 1.5  # Thicker horizontal lines (1.0 = no change)
@export var horizontal_line_darken: float = 0.08  # Darken horizontal lines (0.0-1.0)
@export var trail_line_width: float = 3.0
@export var trail_dot_length: float = 4.0
@export var trail_dot_gap: float = 3.0
@export var trail_dot_size_variation: float = 0.0
@export var trail_dot_spacing_variation: float = 0.0
@export var trail_outline_width: float = 1.0

@export_group("Landmass")
@export var enable_landmass_shading: bool = true
@export var landmass_coast_darken: float = 0.3  # How much darker at coast (0.0-1.0)
@export var landmass_gradient_distance: float = 100.0  # Distance from coast where gradient fades
@export var curve_strength: float = 0.3  # How much curves bend (0.0 = straight, 0.5 = strong)
@export var s_curve_threshold: float = 50.0  # Distance above which S-curves become more likely
@export var s_curve_probability: float = 0.6  # Probability of S-curve for long paths

@export_group("Coast")
@export var coastal_neighbor_weight_when_mixed: float = 0.5  # Weight when mixed with non-coastal (0.0-1.0)

@export_group("Coastal Water Blobs")
@export var enable_coastal_water_blobs: bool = true
@export var coastal_water_expansion: float = 35.0
@export var coastal_water_radius: float = 145.0
@export var coastal_water_circles: int = 8
@export var coastal_water_alpha_max: float = 0.45

@export_group("Coastal Ripples")
@export var enable_coast_ripples: bool = true
@export var ripple_count: int = 3
@export var ripple_base_spacing: float = 12.0
@export var ripple_spacing_growth: float = 1.2  # Each ripple further than the last (multiplier)
@export var ripple_base_width: float = 2.0
@export var ripple_width_decay: float = 0.7  # Each ripple width as fraction of previous
@export var ripple_color_fade: float = 0.25  # How much lighter each successive ripple (added to RGB)
@export var ripple_alpha_decay: float = 0.7  # Each ripple alpha as fraction of previous

@export_group("Hover Preview")
@export var preview_path_dot_size: float = 5.0
@export var preview_path_dot_gap: float = 4.0
@export var enable_pass1: bool = true  # Process all nodes with 3+ connections
@export var enable_pass2: bool = true  # Process nodes with exactly 2 connections
@export var use_curved_lines: bool = true  # Use smooth curves instead of straight lines

@export_group("Regions")
@export var region_count: int = 6

@export_group("Mountains")
@export var enable_mountains: bool = true

@export_group("Biome Blobs")
@export var enable_biome_blobs: bool = true
@export var biome_blob_radius: float = 55.0
@export var biome_blob_circles: int = 6
@export var biome_blob_alpha_max: float = 0.175

@export_group("Map Features")
@export var enable_map_features: bool = true
@export var enable_rivers: bool = false
@export var river_source_width: float = 4.0  # Width at river source (mountain)
@export var river_end_width: float = 2.0  # Width at river end (coast/lake)
@export var lake_radius_x: float = 15.0  # Horizontal radius of lake ellipses
@export var lake_radius_y: float = 10.0  # Vertical radius of lake ellipses (squished)
@export var river_center_randomness: float = 1.5  # Multiplier of poisson_min_distance for center offset
@export var river_curve_smoothness: int = 8  # Points to interpolate between each waypoint pair (higher = smoother)
@export var river_horizontal_width_multiplier: float = 1.5  # Width multiplier for horizontal segments (1.0 = no effect)
@export var river_noise_amplitude: float = 1.5  # How much rivers wiggle perpendicular to their path (0 = none)
@export var river_noise_frequency: float = 0.3  # How often the wiggle changes (lower = smoother, higher = more chaotic)
@export var river_waypoint_randomness: float = 0.8  # Random offset for intermediate waypoints (multiplier of poisson_min_distance)
@export var river_simplify_distance: float = 5.0  # Merge waypoints closer than this distance (0 = disabled)

@export_group("River Spawn Rates by Biome")
@export_range(0.0, 1.0) var river_spawn_rate_forest: float = 1.0  # 100% spawn rate in forests
@export_range(0.0, 1.0) var river_spawn_rate_plains: float = 0.8  # 80% spawn rate in plains
@export_range(0.0, 1.0) var river_spawn_rate_swamp: float = 1.0  # 100% spawn rate in swamps
@export_range(0.0, 1.0) var river_spawn_rate_mountain: float = 0.5  # 50% spawn rate in mountains
@export_range(0.0, 1.0) var river_spawn_rate_badlands: float = 0.3  # 30% spawn rate in badlands
@export_range(0.0, 1.0) var river_spawn_rate_ash_plains: float = 0.0  # 0% spawn rate in ash plains

@export_group("Inter-Region River Connections")
@export_range(0.0, 1.0) var inter_region_river_chance: float = 0.3  # Chance for non-mountainous borders to spawn connecting rivers

@export_group("General")
@export var feature_debug_output: bool = false  # Print detailed feature generation info

# Legacy river exports (not used in new intelligent river system)
# @export var river_merge_distance: float = 20.0
# @export var river_tributary_bonus: float = 1.5

@export_group("Performance")
@export var use_static_rendering: bool = true  # Bake static elements to texture
@export var map_resolution_scale: float = 2.0  # Scale factor for static map texture (higher = crisper when zoomed)

@export_group("Error Handling")
@export var auto_regenerate_on_error: bool = true

@export_group("Debug")
@export var enable_debug_output: bool = false  # Enable/disable debug print statements

@export_group("Map Decorations")
@export var enable_map_decorations: bool = true
@export var decoration_distance_from_coast: float = 150.0
@export var decoration_edge_margin: float = 50.0  # Minimum distance from screen edges

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
var rested_at_node_index: int = -1  # Track which node was rested at (reset when party leaves)

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
@onready var party_indicator: Sprite2D = $MapSprites/PartyIndicator
@onready var mapnodes: Control = $MapNodes
@onready var world_name_label: Label = $MapDetails/Control/WorldNameLabel
@onready var game_camera: Camera2D = $GameCamera

# LocationDetailDisplay and RestButton now live in MapUI under Main's UIController (use unique names)

# Static map rendering (performance optimization)
@onready var static_map_viewport: SubViewport = $StaticMapViewport
@onready var static_map_renderer: StaticMapRenderer = $StaticMapViewport/StaticMapRenderer
@onready var static_map_sprite: Sprite2D = $MapSprites/StaticMapSprite
@onready var dagron_sprite: Sprite2D = $MapSprites/ThereBeDagrons
@onready var octopi_sprite: Sprite2D = $MapSprites/ThereBeOctopi
@onready var waves_east_sprite: Sprite2D = $MapSprites/WavesE
@onready var waves_west_sprite: Sprite2D = $MapSprites/WavesW
@onready var waves_northwest_sprite: Sprite2D = $MapSprites/WavesNW
@onready var waves_southeast_sprite: Sprite2D = $MapSprites/WavesSE


# ============================================================================
# SIGNALS
# ============================================================================

signal map_generation_complete
signal party_moved_to_node(node: MapNode2D)  # Emitted when party moves to a new node
signal travel_completed(node: MapNode2D)  # Emitted when party finishes traveling to a node

# ============================================================================
# INTERNAL VARIABLES
# ============================================================================

var _regeneration_requested: bool = false

var map_nodes: Array[MapNode2D] = []
var node_positions: Array[Vector2] = []
var coastal_nodes: Array[MapNode2D] = []
var coastal_connections: Array = []  # Stored pairs [node_a, node_b] for coastal edges
var expanded_coast_lines: Array = []  # Array of [pos_a, pos_b] for expanded coast lines
var expanded_coast_positions: Dictionary = {}  # node_index -> expanded Vector2 position (cached)
var coast_expansion_factors: Dictionary = {}  # node_index -> expansion factor (0.0-1.0) for variance
var map_features: Array = []  # Array of feature dictionaries (trees, rocks, etc.)
var rivers: Array = []  # Array of river dictionaries
var astar: AStar2D

# Roads and towns
var road_edges: Dictionary = {}  # key: "nodeA_nodeB" (smaller index first), value: true if road
var town_nodes: Array[MapNode2D] = []  # All nodes that are towns
var region_focal_points: Dictionary = {}  # region_id -> Array of focal point nodes
var coast_noise: FastNoiseLite  # Noise for spatially coherent coast expansion variance

# Secret paths
var border_edges: Dictionary = {}  # key: "nodeA_nodeB", value: true if border between regions
var secret_edges: Dictionary = {}  # key: "nodeA_nodeB", value: { is_secret: bool, is_revealed: bool }

# Regions and rivers
var regions: Dictionary = {}  # region_id -> Region object
var river_data: Array = []  # Array of river path data for rendering

# Triangle centers for decoration placement
var border_triangle_centers: Array[Dictionary] = []  # Triangles spanning 2 regions: { center: Vector2, regions: [id1, id2] }
var triple_border_triangle_centers: Array[Dictionary] = []  # Triangles spanning 3 regions: { center: Vector2, regions: [id1, id2, id3] }

# Shape noise
var shape_noise_large: FastNoiseLite
var shape_noise_small: FastNoiseLite
var current_noise_intensity: float = 0.0
var current_large_scale_weight: float = 0.0
var current_small_scale_weight: float = 0.0

# Delaunay triangulation
var delaunay_edges: Array = []  # Array of [Vector2, Vector2] edges

# Biome resources
var biome_forest: Biome = null
var biome_plains: Biome = null
var biome_swamp: Biome = null
var biome_mountain: Biome = null
var biome_badlands: Biome = null
var biome_ash_plains: Biome = null

# ============================================================================
# CORE GENERATION
# ============================================================================

## Debug print helper - only prints if enable_debug_output is true
func debug_print(message: String):
	if enable_debug_output:
		print(message)

func _ready():
	# Set to fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ensure we draw on top of backgrounds
	z_index = 1
	# Load biome resources
	_load_biome_resources()
	
	# Initialize coast expansion noise for spatially coherent variance
	coast_noise = FastNoiseLite.new()
	coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coast_noise.frequency = 0.5  # Will be overridden by coast_expansion_noise_scale
	coast_noise.seed = randi()  # Random seed for variation between maps
	
	# Map generation will be triggered manually when game starts
	
	# Rest button is now in MapUI under UIController - Main connects to map_ui.rest_requested
	
	# Hide decoration sprites initially
	if dagron_sprite:
		dagron_sprite.visible = false
	if octopi_sprite:
		octopi_sprite.visible = false
	if waves_east_sprite:
		waves_east_sprite.visible = false
	if waves_west_sprite:
		waves_west_sprite.visible = false
	if waves_northwest_sprite:
		waves_northwest_sprite.visible = false
	if waves_southeast_sprite:
		waves_southeast_sprite.visible = false

## Set the world name and update the label
func set_world_name(name: String):
	if world_name_label:
		world_name_label.text = name


## initialize_party_ui moved to Main - calls ui_controller.map_ui.initialize_party_ui()


func generate_map():
	debug_print("=== Starting 2D Map Generation ===")
	
	# Hide nodes during generation
	if mapnodes:
		mapnodes.visible = false
	
	# Step 1: Clear existing
	debug_print("Step 1: Clearing existing nodes...")
	clear_existing_nodes()
	
	# Step 2: Initialize shape noise
	debug_print("Step 2: Initializing shape noise...")
	initialize_shape_noise()
	
	# Step 3: Generate positions (Poisson-disk sampling)
	debug_print("Step 3: Generating node positions...")
	generate_poisson_positions()
	
	# Step 4: Instantiate nodes
	debug_print("Step 4: Instantiating nodes...")
	instantiate_nodes()
	
	# Step 5: Wait for nodes to be added
	await get_tree().process_frame
	
	# Step 6: Center at origin
	debug_print("Step 6: Centering points at origin...")
	center_points_at_origin()
	
	# Step 6.5: Rotate to horizontal (after centering, before connections)
	if enable_rotation:
		debug_print("Step 6.5: Rotating to horizontal...")
		rotate_to_horizontal()
		
		# Step 6.6: Vertically center after rotation
		debug_print("Step 6.6: Vertically centering nodes...")
		vertically_center_nodes()
	
	# Step 7: Generate connections (Delaunay)
	debug_print("Step 7: Generating connections (Delaunay)...")
	generate_delaunay_connections()
	
	# Step 8: Filter edges by distance (optional)
	if enable_distance_filtering:
		debug_print("Step 8: Filtering edges by distance...")
		filter_edges_by_distance()
	
	# Step 8.25: Filter edges by minimum angle (prevent very small angles)
	debug_print("Step 8.25: Filtering edges by minimum angle...")
	filter_edges_by_angle()
	
	# Step 8.5: Validate nodes and connections (check for duplicates/overlaps)
	debug_print("Step 8.5: Validating nodes and connections...")
	validate_nodes()
	
	# Step 9: Identify coastal nodes (BEFORE mountains, so connections are intact)
	debug_print("Step 9: Identifying coastal nodes...")
	identify_coastal_nodes()
	
	# Step 10: Build AStar2D graph
	debug_print("Step 10: Building AStar2D pathfinding graph...")
	build_astar_graph()
	
	# Step 11: Identify points of interest
	debug_print("Step 11: Identifying points of interest...")
	identify_points_of_interest()
	
	# Step 12: Create regions
	debug_print("Step 12: Creating regions...")
	create_regions()
	
	# Step 11.5: Identify border edges (exit paths between regions)
	debug_print("Step 11.5: Identifying border edges...")
	identify_border_edges()
	
	# Step 12.5: Generate mountains at region boundaries
	if enable_mountains:
		debug_print("Step 12.5: Generating mountains at region boundaries...")
		generate_mountains_at_borders()
		
		# Step 12.55: Center mountain nodes at average position of connected nodes
		debug_print("Step 12.55: Centering mountain nodes...")
		center_mountain_nodes()
		
		# Step 12.6: Disconnect ONLY mountain-to-mountain connections (prevent rivers through mountains)
		debug_print("Step 12.6: Disconnecting inter-mountain connections...")
		disconnect_inter_mountain_connections()
		
		# Step 12.65: Complete region analysis (now that mountains exist)
		debug_print("Step 12.65: Completing region analysis...")
		complete_region_analysis()
	
	# Step 12.7: Assign biomes to all nodes
	debug_print("Step 12.7: Assigning biomes to nodes...")
	assign_biomes()
	
	# Step 12.71: Populate region biomes (now that nodes have biomes)
	debug_print("Step 12.71: Populating region biomes...")
	populate_region_biomes()
	
	# Step 12.75: Mark exit nodes (nodes connecting to different regions)
	debug_print("Step 12.75: Marking exit nodes...")
	mark_exit_nodes()
	
	# Step 12.77: Generate towns per region (AFTER marking exits so we can sort by exit distance)
	debug_print("Step 12.77: Generating towns per region...")
	generate_towns()
	
	# Step 12.78: Assign focal points for each region
	debug_print("Step 12.78: Assigning regional focal points...")
	assign_region_focal_points()
	
	# Step 12.79: Generate roads connecting regions
	debug_print("Step 12.79: Generating roads between regions...")
	generate_roads()
	
	# Step 12.795: Extend dead-end roads toward coast
	if coastal_extension_count > 0:
		debug_print("Step 12.795: Extending dead-end roads to coast...")
		extend_deadends_to_coast()
	
	# Step 12.797: Identify and categorize triangle centers for decoration placement
	debug_print("Step 12.797: Identifying triangle centers...")
	identify_triangle_centers()
	
	# Step 12.8: Identify secret path candidates
	debug_print("Step 12.8: Identifying secret paths...")
	identify_secret_path_candidates()
	
	# Step 12.85: Generate map features (trees, decorations, etc.)
	if enable_map_features:
		debug_print("Step 12.8: Generating map features...")
		generate_map_features()
	
	# Step 12.9: Generate rivers (with mountains still connected)
	if enable_rivers:
		debug_print("Step 12.9: Generating rivers...")
		generate_rivers()
	else:
		debug_print("Step 12.9: River generation DISABLED (enable_rivers = false)")
	
	# Step 12.91: NOW disconnect mountains (after river generation)
	if enable_mountains:
		debug_print("Step 12.91: Disconnecting mountain nodes for pathfinding...")
		disconnect_mountain_nodes()
		debug_print("Step 12.92: Disabling mountains in AStar2D...")
		disable_mountains_in_astar()
	
	# Check if regeneration was requested due to errors (BEFORE visualizing)
	if _regeneration_requested:
		_regeneration_requested = false
		debug_print("=== Regenerating map due to detected errors ===")
		regenerate_map()
		return
	
	# Step 13: Visualize (only if no errors detected)
	debug_print("Step 13: Visualizing map...")
	visualize_map()
	
	# Step 13.5: Bake static elements (if enabled)
	if use_static_rendering:
		debug_print("Step 13.5: Baking static map elements...")
		await bake_static_map()
	
	# Step 13.6: Position map decorations (dragons, octopi, etc.)
	if enable_map_decorations:
		debug_print("Step 13.6: Positioning map decorations...")
		position_map_decorations()
	
	debug_print("=== 2D Map Generation Complete ===")
	
	# Enable camera when game starts and set its limits based on control size
	if game_camera:
		debug_print("camera: MapGenerator Control size=%s, global_position=%s" % [size, global_position])
		game_camera.enabled = true
		# Wait a frame for Control size to be properly set, then set camera limits
		await get_tree().process_frame
		debug_print("camera: After frame wait, MapGenerator Control size=%s" % size)
		game_camera.set_map_limits(size)
	else:
		debug_print("camera: ERROR - game_camera is null!")
	
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
			# Reset secret path properties before freeing
			if node is MapNode2D:
				node.has_secret_path = false
				node.secret_path_revealed = false
			node.queue_free()
	map_nodes.clear()
	node_positions.clear()
	coastal_nodes.clear()
	coastal_connections.clear()
	expanded_coast_lines.clear()
	expanded_coast_positions.clear()
	coast_expansion_factors.clear()
	rivers.clear()
	delaunay_edges.clear()
	visited_paths.clear()
	current_travel_path.clear()
	road_edges.clear()
	town_nodes.clear()
	region_focal_points.clear()
	border_edges.clear()
	secret_edges.clear()
	regions.clear()
	river_data.clear()
	
	# Hide decoration sprites during regeneration
	if dagron_sprite:
		dagron_sprite.visible = false
	if octopi_sprite:
		octopi_sprite.visible = false
	if waves_east_sprite:
		waves_east_sprite.visible = false
	if waves_west_sprite:
		waves_west_sprite.visible = false
	if waves_northwest_sprite:
		waves_northwest_sprite.visible = false
	if waves_southeast_sprite:
		waves_southeast_sprite.visible = false
	
	if is_inside_tree():
		queue_redraw()  # Clear drawn lines

# ============================================================================
# STEP 2: INITIALIZE SHAPE NOISE
# ============================================================================

func initialize_shape_noise():
	# Determine noise intensity
	if randf() < shape_noise_chance_off or not shape_noise_enabled:
		current_noise_intensity = 0.0
		debug_print("  Shape noise: DISABLED (pure ellipse)")
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
	
	debug_print("  Noise intensity: %.2f" % current_noise_intensity)

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
	
	debug_print("  Generated %d nodes" % node_positions.size())

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
	
	debug_print("  Instantiated %d nodes" % map_nodes.size())

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
		debug_print("  WARNING: Found %d overlapping node pairs:" % overlapping_pairs.size())
		for pair in overlapping_pairs:
			debug_print("    Nodes %d and %d are %.2f units apart" % [pair[0], pair[1], pair[2]])
	
	# Check for duplicate connections in node connection lists
	var duplicate_connections = 0
	for node in map_nodes:
		var seen_neighbors: Dictionary = {}
		for neighbor in node.connections:
			if seen_neighbors.has(neighbor.node_index):
				duplicate_connections += 1
				debug_print("  WARNING: Node %d has duplicate connection to node %d" % [node.node_index, neighbor.node_index])
			else:
				seen_neighbors[neighbor.node_index] = true
		
		# Also check if node is connected to itself
		if seen_neighbors.has(node.node_index):
			debug_print("  ERROR: Node %d is connected to itself!" % node.node_index)
	
	if duplicate_connections > 0:
		debug_print("  WARNING: Found %d duplicate connections" % duplicate_connections)
	
	# Check for asymmetric connections (A has B but B doesn't have A)
	var asymmetric_connections = 0
	for node in map_nodes:
		for neighbor in node.connections:
			if node not in neighbor.connections:
				asymmetric_connections += 1
				debug_print("  ERROR: Asymmetric connection: Node %d has %d, but %d doesn't have %d" % [node.node_index, neighbor.node_index, neighbor.node_index, node.node_index])
	
	if asymmetric_connections > 0:
		debug_print("  ERROR: Found %d asymmetric connections" % asymmetric_connections)
	else:
		debug_print("  Node validation passed (no overlaps, duplicates, or asymmetric connections)")

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
	
	debug_print("  Centered at screen (offset: %.1f, %.1f)" % [offset.x, offset.y])

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
	
	debug_print("  Furthest nodes: %d and %d (distance: %.1f)" % [node_a.node_index, node_b.node_index, max_distance])
	
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
	debug_print("  Rotated by %.1f degrees around center (%.1f, %.1f)" % [angle_degrees, center.x, center.y])

# ============================================================================
# STEP 6.6: VERTICALLY CENTER NODES
# ============================================================================

func vertically_center_nodes():
	if map_nodes.size() == 0:
		debug_print("  ERROR: No nodes to vertically center!")
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
	
	debug_print("  DEBUG: Bounding box Y range: %.1f to %.1f (center: %.1f)" % [min_y, max_y, bounding_box_center_y])
	debug_print("  DEBUG: Screen center Y: %.1f, Offset: %.1f" % [screen_center_y, y_offset])
	
	# Shift all nodes vertically
	for node in map_nodes:
		node.position.y += y_offset
	
	debug_print("  Vertically centered (y offset: %.1f)" % y_offset)

# ============================================================================
# STEP 7: DELAUNAY TRIANGULATION
# ============================================================================

func generate_delaunay_connections():
	delaunay_edges.clear()
	
	if map_nodes.size() < 3:
		debug_print("  Not enough nodes for triangulation")
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
	
	debug_print("  Created %d edges" % delaunay_edges.size())

# ============================================================================
# STEP 8: FILTER EDGES (OPTIONAL)
# ============================================================================

func filter_edges_by_distance():
	var max_dist = poisson_min_distance * max_connection_distance_multiplier
	var removed_count = 0
	
	debug_print("  Filtering edges longer than %.1f units..." % max_dist)
	
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
	
	debug_print("  Removed %d long edges, %d remaining" % [removed_count / 2, delaunay_edges.size()])

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
	
	debug_print("  Removed %d edges with angles smaller than %.1f degrees" % [removed_count, min_angle_threshold_degrees])

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
			debug_print("  DEBUG: Node %d on boundary edge %s was not marked coastal! Fixing..." % [node_a_idx, boundary.edge])
			node_a_found.is_coastal = true
			verification_fixes += 1
		if not node_b_found.is_coastal:
			debug_print("  DEBUG: Node %d on boundary edge %s was not marked coastal! Fixing..." % [node_b_idx, boundary.edge])
			node_b_found.is_coastal = true
			verification_fixes += 1
	
	# Collect all coastal nodes
	for node in map_nodes:
		if node.is_coastal:
			coastal_nodes.append(node)
			# Color coastal nodes white for visibility
			node.set_debug_color(Color.WHITE)
	
	if verification_fixes > 0:
		debug_print("  WARNING: Fixed %d nodes that should have been marked coastal" % verification_fixes)
	
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
		debug_print("  Fixed %d missing coastal edge connections" % fixed_coastal_edges)
	
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
		debug_print("  Removed %d interior loop nodes incorrectly marked as coastal" % removed_count)
	
	debug_print("  Identified %d coastal nodes with %d coastal connections (found %d boundary edges)" % [coastal_nodes.size(), coastal_connections.size(), boundary_edge_data.size()])
	
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
		debug_print("  No loops found in coastal connections")
		return
	
	var largest_loop: Array = all_loops[0]
	var largest_size = all_loops[0].size()
	for loop in all_loops:
		if loop.size() > largest_size:
			largest_loop = loop
			largest_size = loop.size()
	
	debug_print("  Found %d loops, largest loop has %d nodes (main boundary)" % [all_loops.size(), largest_size])
	
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
			debug_print("  INTERIOR LOOP FOUND: %s (shares nodes with main boundary)" % str(loop))
	
	if interior_loops.size() > 0:
		debug_print("  Identified %d interior loops" % interior_loops.size())
	else:
		debug_print("  No interior loops found")

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
	
	# Generate spatially coherent expansion factors using noise
	coast_expansion_factors.clear()
	for node in coastal_nodes:
		var node_center = node.position + (node.size / 2.0)
		# Sample noise at this position for spatially coherent variance
		var noise_value = coast_noise.get_noise_2d(node_center.x * coast_expansion_noise_scale, node_center.y * coast_expansion_noise_scale)
		# Noise returns -1 to 1, normalize to 0 to 1
		var normalized_noise = (noise_value + 1.0) / 2.0
		coast_expansion_factors[node.node_index] = normalized_noise
	
	# Use away_directions to calculate expanded positions and CACHE them
	expanded_coast_positions.clear()
	
	for node in coastal_nodes:
		var node_center = node.position + (node.size / 2.0)
		# Use the stored away_direction angle
		var away_vector = Vector2(cos(node.away_direction), sin(node.away_direction))
		# Get this node's expansion factor and interpolate between min and max
		var expansion_factor = coast_expansion_factors.get(node.node_index, 0.5)
		var expansion_distance = lerp(coast_expansion_min, coast_expansion_max, expansion_factor)
		var expanded_pos = node_center + away_vector * expansion_distance
		expanded_coast_positions[node.node_index] = expanded_pos
	
	# Third pass: create lines between expanded vertices using original connections
	for connection in coastal_connections:
		var node_a = connection[0]
		var node_b = connection[1]
		
		var expanded_a = expanded_coast_positions.get(node_a.node_index)
		var expanded_b = expanded_coast_positions.get(node_b.node_index)
		
		if expanded_a != null and expanded_b != null:
			expanded_coast_lines.append([expanded_a, expanded_b])
	
	debug_print("  Generated %d expanded coast lines from %d coastal nodes (%d connections)" % [expanded_coast_lines.size(), coastal_nodes.size(), coastal_connections.size()])

# ============================================================================
# COAST EXPANSION: AWAY DIRECTION CALCULATION
# ============================================================================

func calculate_away_directions_pass1():
	# PASS 1: ALL coastal nodes with 3+ connections
	debug_print("  PASS 1: Processing ALL coastal nodes with 3+ connections...")
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
		debug_print("    PASS 1: Node %d (connections=%d, coastal_neighbors=%d, non_coastal_neighbors=%d)" % [node.node_index, node.connections.size(), coastal_neighbors.size(), non_coastal_neighbors.size()])
		
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
			debug_print("      Node %d: Checking %d coastal neighbors for coastal edges..." % [node.node_index, coastal_neighbors.size()])
			for neighbor in coastal_neighbors:
				# Check if the edge between node and neighbor is in coastal_connections
				var edge_is_coastal = false
				for connection in coastal_connections:
					if (connection[0] == node and connection[1] == neighbor) or (connection[0] == neighbor and connection[1] == node):
						edge_is_coastal = true
						break
				
				debug_print("        Neighbor %d: edge_is_coastal=%s" % [neighbor.node_index, edge_is_coastal])
				if edge_is_coastal:
					coastal_neighbors_with_coastal_edges.append(neighbor)
			
			# There should be exactly 2 coastal neighbors with coastal edges
			if coastal_neighbors_with_coastal_edges.size() != 2:
				_handle_generation_error("Node %d has %d coastal neighbors with coastal edges (expected 2)" % [node.node_index, coastal_neighbors_with_coastal_edges.size()])
				debug_print("      ERROR: Expected 2, got %d. Using fallback (first 2 coastal neighbors)" % coastal_neighbors_with_coastal_edges.size())
				# Fallback: use first two coastal neighbors
				coastal_neighbors_with_coastal_edges = [coastal_neighbors[0], coastal_neighbors[1]]
			
			var coastal_1 = coastal_neighbors_with_coastal_edges[0]
			var coastal_2 = coastal_neighbors_with_coastal_edges[1]
			debug_print("      SELECTED: Using neighbors %d and %d for arc calculation" % [coastal_1.node_index, coastal_2.node_index])
			
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
			
			debug_print("      Checking other neighbors for arc classification:")
			debug_print("      Arc 1 range: %.1f° to %.1f°" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end)])
			debug_print("      Arc 2 range: %.1f° to %.1f° (wrapping)" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU)])
			
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
				
				debug_print("        Neighbor %d: angle=%.1f°, in_arc1=%s (check: %.1f >= %.1f AND %.1f <= %.1f)" % [
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
					debug_print("          → Classified as ARC 1")
				else:
					# Must be in arc 2 (the two arcs cover the full circle)
					other_neighbors_in_arc2 = true
					debug_print("          → Classified as ARC 2")
			
			# Calculate candidate angles
			var candidate_arc1 = arc_1_start + arc_1_span / 2.0
			var candidate_arc2 = (arc_1_end + arc_2_span / 2.0)
			if candidate_arc2 >= TAU:
				candidate_arc2 -= TAU
			
			debug_print("      Candidate angles: Arc1_midpoint=%.1f°, Arc2_midpoint=%.1f°" % [rad_to_deg(candidate_arc1), rad_to_deg(candidate_arc2)])
			debug_print("      Neighbors in arc1: %s, Neighbors in arc2: %s" % [other_neighbors_in_arc1, other_neighbors_in_arc2])
			
			# Pick the midpoint of the arc OPPOSITE to where other neighbors lie
			# If neighbors are in arc 1, use arc 2's midpoint
			# If neighbors are in arc 2, use arc 1's midpoint
			if other_neighbors_in_arc1 and not other_neighbors_in_arc2:
				# Neighbors are in arc 1, use arc 2
				away_angle = candidate_arc2
				debug_print("      DECISION: Neighbors in ARC 1 → Use ARC 2 candidate = %.1f°" % rad_to_deg(away_angle))
			elif other_neighbors_in_arc2 and not other_neighbors_in_arc1:
				# Neighbors are in arc 2, use arc 1
				away_angle = candidate_arc1
				debug_print("      DECISION: Neighbors in ARC 2 → Use ARC 1 candidate = %.1f°" % rad_to_deg(away_angle))
			else:
				# ERROR: Neighbors in both arcs or neither - this should be impossible
				_handle_generation_error("Node %d: ERROR - Neighbors found in both arcs or neither! arc1=%s, arc2=%s" % [node.node_index, other_neighbors_in_arc1, other_neighbors_in_arc2])
				debug_print("      ERROR: Cannot determine which arc neighbors are in!")
				debug_print("      Arc 1: %.1f° to %.1f°" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end)])
				debug_print("      Arc 2: %.1f° to %.1f° (wrapping)" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU)])
				# Fallback: use arc 1 midpoint
				away_angle = candidate_arc1
				debug_print("      FALLBACK: Using ARC 1 candidate = %.1f°" % rad_to_deg(away_angle))
		
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
		debug_print("      → Set away_direction=%.1f° for node %d" % [rad_to_deg(away_angle), node.node_index])
	
	debug_print("  PASS 1: Processed %d nodes" % processed_count)

func calculate_away_directions_pass2():
	# PASS 2: Coastal nodes with exactly 2 connections
	for node in coastal_nodes:
		if node.connections.size() != 2:
			continue
		
		debug_print("  PASS 2: Node %d (2 connections)" % node.node_index)
		
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
		
		debug_print("    Neighbor 1 (node %d): angle=%.1f° (%.2f rad), is_coastal=%s, away_direction=%.1f°" % [neighbor_1.node_index, rad_to_deg(angle_1), angle_1, neighbor_1.is_coastal, rad_to_deg(neighbor_1.away_direction) if neighbor_1.away_direction != 0.0 else 0.0])
		debug_print("    Neighbor 2 (node %d): angle=%.1f° (%.2f rad), is_coastal=%s, away_direction=%.1f°" % [neighbor_2.node_index, rad_to_deg(angle_2), angle_2, neighbor_2.is_coastal, rad_to_deg(neighbor_2.away_direction) if neighbor_2.away_direction != 0.0 else 0.0])
		
		# Calculate both candidate away angles
		var arc_1_start = min(angle_1, angle_2)
		var arc_1_end = max(angle_1, angle_2)
		var arc_1_span = arc_1_end - arc_1_start
		var arc_2_span = TAU - arc_1_span
		
		var candidate_1 = arc_1_start + arc_1_span / 2.0  # Midpoint of arc 1
		var candidate_2 = arc_1_end + arc_2_span / 2.0   # Midpoint of arc 2
		if candidate_2 >= TAU:
			candidate_2 -= TAU
		
		debug_print("    Arc 1: %.1f° to %.1f° (span=%.1f°), candidate=%.1f°" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end), rad_to_deg(arc_1_span), rad_to_deg(candidate_1)])
		debug_print("    Arc 2: %.1f° to %.1f° (span=%.1f°), candidate=%.1f°" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU), rad_to_deg(arc_2_span), rad_to_deg(candidate_2)])
		
		# Find which candidate is closest to neighboring coastal nodes' away_directions
		var use_candidate_1 = true
		var selection_reason = ""
		
		# Check if we have neighboring coastal nodes with away_directions already set
		var has_coastal_neighbors_with_away = false
		var total_distance_to_candidate_1 = 0.0
		var total_distance_to_candidate_2 = 0.0
		var neighbor_count = 0
		
		debug_print("    Checking neighbors' away_directions:")
		for neighbor in node.connections:
			var away_str = "%.1f° (raw=%.4f)" % [rad_to_deg(neighbor.away_direction), neighbor.away_direction] if neighbor.away_direction != 0.0 else "NOT SET (0.0)"
			debug_print("      Neighbor %d: is_coastal=%s, away_direction=%s" % [neighbor.node_index, neighbor.is_coastal, away_str])
			
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
				
				debug_print("        → USING: away_direction=%.1f°, dist_to_c1=%.1f°, dist_to_c2=%.1f°" % [rad_to_deg(neighbor_away), rad_to_deg(dist_to_c1), rad_to_deg(dist_to_c2)])
			else:
				if neighbor.is_coastal:
					debug_print("        → SKIPPING: is_coastal but away_direction not set (value=%.4f)" % neighbor.away_direction)
				else:
					debug_print("        → SKIPPING: not coastal")
		
		if has_coastal_neighbors_with_away:
			# Use the candidate that's closer to neighboring away_directions
			use_candidate_1 = total_distance_to_candidate_1 < total_distance_to_candidate_2
			selection_reason = "closer to neighboring away_directions (total dist: c1=%.1f°, c2=%.1f°)" % [rad_to_deg(total_distance_to_candidate_1), rad_to_deg(total_distance_to_candidate_2)]
			debug_print("    DECISION: Using away_direction comparison - total_dist_c1=%.1f°, total_dist_c2=%.1f°" % [rad_to_deg(total_distance_to_candidate_1), rad_to_deg(total_distance_to_candidate_2)])
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
				debug_print("    DECISION: Using non-coastal fallback - neighbor %d at angle=%.1f°" % [non_coastal.node_index, rad_to_deg(angle_nc)])
			else:
				selection_reason = "no away_directions available and both neighbors are coastal, defaulting to candidate_1"
				debug_print("    DECISION: FALLBACK - No away_directions and both neighbors are coastal")
		
		# Set the chosen away direction
		var chosen_candidate = candidate_1 if use_candidate_1 else candidate_2
		node.away_direction = chosen_candidate
		
		debug_print("    SELECTED: Candidate %d (%.1f°) - %s" % [1 if use_candidate_1 else 2, rad_to_deg(chosen_candidate), selection_reason])
		debug_print("")

func validate_all_coastal_nodes_processed():
	# Ensure all coastal nodes have been processed (have away_direction set)
	var unprocessed_nodes: Array[MapNode2D] = []
	for node in coastal_nodes:
		if node.away_direction == 0.0:
			unprocessed_nodes.append(node)
	
	if unprocessed_nodes.size() > 0:
		_handle_generation_error("ERROR: %d coastal nodes were not processed!" % unprocessed_nodes.size())
		debug_print("  Unprocessed coastal nodes:")
		for node in unprocessed_nodes:
			debug_print("    Node %d: connections=%d" % [node.node_index, node.connections.size()])
	else:
		debug_print("  ✓ All %d coastal nodes have been processed" % coastal_nodes.size())

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
	
	debug_print("  Built AStar2D with %d points" % astar.get_point_count())

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
		debug_print("  Identified lonely mountain at node %d" % most_isolated.node_index)

# ============================================================================
# STEP 12: CREATE REGIONS
# ============================================================================

func create_regions():
	# Simple region assignment: divide nodes into N groups
	# All nodes (including coastal) get assigned to regions
	
	if map_nodes.size() == 0:
		return
	
	# Pick random seed nodes from ALL nodes
	var seeds = []
	for i in range(min(region_count, map_nodes.size())):
		var random_node = map_nodes[randi() % map_nodes.size()]
		while random_node in seeds:
			random_node = map_nodes[randi() % map_nodes.size()]
		seeds.append(random_node)
		random_node.region_id = i
	
	# Assign all other nodes to nearest seed
	for node in map_nodes:
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
	
	debug_print("  Created %d regions" % region_count)
	
	# Create Region objects for intelligent river generation
	create_region_objects(region_count)

func colorize_regions(num_regions: int):
	# All nodes get the configured node color (export property)
	# Color ALL nodes (including coastal nodes that might not have region_id)
	for node in map_nodes:
		if not node.is_mountain:  # Mountains keep their color
			# Coastal nodes also get the node color
			node.set_region_color(node_base_color)

# ============================================================================
# STEP 11.25: CREATE REGION OBJECTS & ANALYZE BORDERS
# ============================================================================

## Create Region objects with full analysis for intelligent river generation
func create_region_objects(num_regions: int):
	regions.clear()
	debug_print("RIVER: === CREATING REGION OBJECTS ===")
	
	# Step 1: Create Region objects and assign nodes
	for i in range(num_regions):
		var region = Region.new()
		region.region_id = i
		# Biome will be set later after assign_biomes() is called
		region.biome = null
		regions[i] = region
	
	# Collect nodes into their regions
	for node in map_nodes:
		if node.region_id >= 0 and node.region_id < num_regions:
			regions[node.region_id].add_node(node)
	
	debug_print("RIVER:   Created %d region objects" % regions.size())
	
	# Step 2: Identify borders and adjacent regions
	identify_region_borders()
	
	# Step 3: Mountainous borders - DEFERRED until after mountains are generated
	# Step 4: Coastal status - DEFERRED until after coast identification
	# Step 5: Regional centrality - DEFERRED until AStar is built
	
	debug_print("RIVER: === REGION OBJECTS CREATED (analysis deferred) ===")

## Complete region analysis after mountains and coasts are established
func complete_region_analysis():
	debug_print("RIVER: === COMPLETING REGION ANALYSIS ===")
	
	# Step 0: Calculate global interiorness scores (needed for meandering rivers)
	calculate_global_interiorness_scores()
	
	# Step 0.5: Calculate regional interiorness (average of node scores)
	calculate_regional_interiorness()
	
	# Step 1: Determine which borders are mountainous (now that mountains exist)
	identify_mountainous_borders()
	
	# Step 2: Identify coastal status (should already be done, but verify)
	identify_region_coastal_status()
	
	# Step 3: Calculate regional centrality (now that AStar is built)
	calculate_regional_centrality()
	
	debug_print("RIVER: === REGION ANALYSIS COMPLETE ===")

## Calculate global interiorness score for each node (average distance to coast)
## Higher score = more interior, Lower score = closer to coast
func calculate_global_interiorness_scores():
	debug_print("RIVER:   Calculating global interiorness scores...")
	
	if not astar:
		debug_print("RIVER:     WARNING: AStar not initialized")
		return
	
	if coastal_nodes.size() == 0:
		debug_print("RIVER:     WARNING: No coastal nodes found")
		return
	
	var non_mountain_nodes: Array[MapNode2D] = []
	for node in map_nodes:
		if not node.is_mountain:
			non_mountain_nodes.append(node)
	
	# Calculate for each non-mountain node
	for node in non_mountain_nodes:
		var total_distance = 0
		var valid_coastal_count = 0
		
		# Calculate distance to ALL coastal nodes
		for coastal_node in coastal_nodes:
			var path = astar.get_id_path(node.node_index, coastal_node.node_index)
			if path.size() > 0:
				total_distance += (path.size() - 1)
				valid_coastal_count += 1
		
		# Average distance to coast = interiorness score
		if valid_coastal_count > 0:
			node.graph_interiorness_score = float(total_distance) / float(valid_coastal_count)
		else:
			# No path to any coast - very interior
			node.graph_interiorness_score = 999.0
	
	# Coastal nodes should have score of 0
	for coastal_node in coastal_nodes:
		coastal_node.graph_interiorness_score = 0.0
	
	# Find min and max for debug
	var min_score = INF
	var max_score = -INF
	for node in non_mountain_nodes:
		min_score = min(min_score, node.graph_interiorness_score)
		max_score = max(max_score, node.graph_interiorness_score)
	
	debug_print("RIVER:     Interiorness scores: min=%.2f, max=%.2f" % [min_score, max_score])

## Calculate average interiorness for each region
func calculate_regional_interiorness():
	debug_print("RIVER:   Calculating regional interiorness...")
	
	for region in regions.values():
		var total_interiorness = 0.0
		var node_count = 0
		
		# Average interiorness of non-mountain nodes
		for node in region.nodes:
			if not node.is_mountain:
				total_interiorness += node.graph_interiorness_score
				node_count += 1
		
		if node_count > 0:
			region.average_interiorness = total_interiorness / node_count
		else:
			region.average_interiorness = 0.0
		
		debug_print("RIVER:     Region %d: avg interiorness = %.2f" % [region.region_id, region.average_interiorness])

## Populate region biomes from nodes (called after assign_biomes)
func populate_region_biomes():
	for region in regions.values():
		# Get biome from first non-mountain node in region
		for node in region.nodes:
			if not node.is_mountain and node.biome != null:
				region.biome = node.biome
				break
		
		if region.biome:
			debug_print("  Region %d: Biome = %s" % [region.region_id, region.biome.biome_name])
		else:
			debug_print("  Region %d: No biome found (all mountains?)" % region.region_id)

## Identify border nodes and adjacent regions for each region
func identify_region_borders():
	debug_print("RIVER:   Analyzing region borders...")
	
	for region in regions.values():
		for node in region.nodes:
			for neighbor in node.connections:
				if neighbor.region_id != node.region_id and neighbor.region_id >= 0:
					# This node is on a border with another region
					if not region.border_nodes.has(neighbor.region_id):
						region.border_nodes[neighbor.region_id] = []
					
					# Add this node to the border with that region (avoid duplicates)
					if node not in region.border_nodes[neighbor.region_id]:
						region.border_nodes[neighbor.region_id].append(node)
					
					# Track adjacent region
					if neighbor.region_id not in region.adjacent_regions:
						region.adjacent_regions.append(neighbor.region_id)
	
	# Debug output
	for region in regions.values():
		debug_print("RIVER:     Region %d borders %d other regions" % [region.region_id, region.adjacent_regions.size()])

## Determine which regional borders are mountainous
func identify_mountainous_borders():
	debug_print("RIVER:   Identifying mountainous borders...")
	
	var total_mountainous = 0
	
	for region in regions.values():
		for adjacent_id in region.adjacent_regions:
			var border_nodes_with_adjacent = region.border_nodes[adjacent_id]
			
			# Check if ANY of these border nodes are mountains
			var has_mountain = false
			for border_node in border_nodes_with_adjacent:
				if border_node.is_mountain:
					has_mountain = true
					break
			
			region.mountainous_borders[adjacent_id] = has_mountain
			
			if has_mountain:
				total_mountainous += 1
	
	debug_print("RIVER:     Found %d mountainous borders total" % total_mountainous)

## Identify which regions are landlocked vs coastal
func identify_region_coastal_status():
	debug_print("RIVER:   Identifying coastal regions...")
	
	var landlocked_count = 0
	var coastal_count = 0
	
	for region in regions.values():
		region.is_landlocked = true
		region.coastal_nodes.clear()
		
		for node in region.nodes:
			if node.is_coastal:
				region.coastal_nodes.append(node)
				region.is_landlocked = false
		
		if region.is_landlocked:
			landlocked_count += 1
		else:
			coastal_count += 1
	
	debug_print("RIVER:     %d coastal regions, %d landlocked regions" % [coastal_count, landlocked_count])

## Calculate regional centrality for each node and find central node per region
func calculate_regional_centrality():
	debug_print("RIVER:   Calculating regional centrality...")
	
	if not astar:
		debug_print("RIVER:     WARNING: AStar not initialized, skipping centrality calculation")
		return
	
	for region in regions.values():
		if region.nodes.size() == 0:
			continue
		
		# Filter to non-coastal, non-mountain nodes for centrality (rivers need interior starting points)
		var interior_nodes: Array[MapNode2D] = []
		for node in region.nodes:
			if not node.is_coastal and not node.is_mountain:
				interior_nodes.append(node)
		
		# Fallback: if no interior nodes, use all non-mountain nodes
		if interior_nodes.size() == 0:
			for node in region.nodes:
				if not node.is_mountain:
					interior_nodes.append(node)
		
		# If still no candidates, use any node
		if interior_nodes.size() == 0:
			interior_nodes = region.nodes.duplicate()
		
		if interior_nodes.size() == 0:
			debug_print("RIVER:     Region %d: No nodes available for centrality!" % region.region_id)
			continue
		
		var best_node: MapNode2D = null
		var best_avg_distance = INF
		
		# For each candidate node, calculate average distance to all other nodes in region
		for node in interior_nodes:
			var total_distance = 0
			var valid_paths = 0
			
			for other_node in region.nodes:
				if node == other_node:
					continue
				
				var path = astar.get_id_path(node.node_index, other_node.node_index)
				if path.size() > 0:
					total_distance += (path.size() - 1)
					valid_paths += 1
			
			# Calculate average distance
			var avg_distance = INF
			if valid_paths > 0:
				avg_distance = float(total_distance) / float(valid_paths)
			
			# Node with minimum average distance is most central
			if avg_distance < best_avg_distance:
				best_avg_distance = avg_distance
				best_node = node
		
		region.central_node = best_node
		
		if best_node:
			# Calculate randomized center position for this region (all rivers will converge here)
			var node_center = best_node.position + (best_node.size / 2.0)
			var max_offset = poisson_min_distance * river_center_randomness
			# Use deterministic seed based on region_id for reproducibility
			var rng = RandomNumberGenerator.new()
			rng.seed = region.region_id * 12345
			var random_offset = Vector2(
				rng.randf_range(-max_offset, max_offset),
				rng.randf_range(-max_offset, max_offset)
			)
			region.randomized_center_position = node_center + random_offset
			
			var is_coastal_str = " (COASTAL!)" if best_node.is_coastal else ""
			debug_print("RIVER:     Region %d: Central node is %d (avg dist: %.1f, interior: %.2f)%s" % [
				region.region_id, 
				best_node.node_index, 
				best_avg_distance,
				best_node.graph_interiorness_score,
				is_coastal_str
			])
		else:
			debug_print("RIVER:     Region %d: No central node found!" % region.region_id)

# ============================================================================
# STEP 11.5: IDENTIFY BORDER EDGES (EXIT PATHS BETWEEN REGIONS)
# ============================================================================

## Identify edges that connect different regions (exit paths)
## These edges will be excluded from secret path candidates
func identify_border_edges():
	border_edges.clear()
	debug_print("SECRET PATH: === IDENTIFYING BORDER EDGES ===")
	
	var border_edge_count = 0
	
	# Iterate through all edges
	for node_a in map_nodes:
		if node_a.is_mountain or node_a.region_id < 0:
			continue
			
		for node_b in node_a.connections:
			if node_b.is_mountain or node_b.region_id < 0:
				continue
			
			# Only process each edge once (smaller index first)
			if node_a.node_index >= node_b.node_index:
				continue
			
			# Check if nodes are in different regions
			if node_a.region_id != node_b.region_id:
				var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
				border_edges[edge_key] = true
				border_edge_count += 1
	
	debug_print("SECRET PATH:   Identified %d border edges connecting different regions" % border_edge_count)

## Helper function - check if an edge is a border edge
func is_border_edge(node_a: MapNode2D, node_b: MapNode2D) -> bool:
	var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
	return border_edges.has(edge_key)

# ============================================================================
# STEP 12.5: GENERATE MOUNTAINS AT REGION BORDERS
# ============================================================================

func generate_mountains_at_borders():
	# Mountain sprite frame distributor (15 frames available)
	var mountain_frame_count: int = 15
	var mountain_frame_usage: Array[int] = []  # Track how many times each frame is used
	for i in range(mountain_frame_count):
		mountain_frame_usage.append(0)
	
	# Helper function to get next frame (uses least-used frame)
	var get_next_mountain_frame = func() -> int:
		var min_usage = mountain_frame_usage.min()
		var available_frames: Array[int] = []
		for i in range(mountain_frame_count):
			if mountain_frame_usage[i] == min_usage:
				available_frames.append(i)
		# Pick randomly from least-used frames
		var frame = available_frames[randi() % available_frames.size()]
		mountain_frame_usage[frame] += 1
		return frame
	
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
	
	debug_print("  Total border nodes found: %d" % border_nodes.size())
	
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
		debug_print("  No border segments found")
		return
	
	debug_print("  Found %d border segments between regions" % border_keys.size())
	
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
			debug_print("    Border Region %d <-> Region %d: FORCED to roll=%d (one region has only 1 border)" % [region_a_id, region_b_id, forced_roll])
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
	debug_print("  Roll distribution: 0=%d, 1=%d, 2=%d, 3=%d" % [roll_counts[0], roll_counts[1], roll_counts[2], roll_counts[3]])
	
	# Step 6: Apply rolls to border segments
	var mountains_created = 0
	
	for key in border_keys:
		var segment_nodes = border_segments[key]
		if segment_nodes.size() == 0:
			continue
		
		var roll = assigned_rolls[key]
		var region_a_id = int(key.split("_")[0])
		var region_b_id = int(key.split("_")[1])
		debug_print("    Border Region %d <-> Region %d: Roll=%d, %d nodes" % [region_a_id, region_b_id, roll, segment_nodes.size()])
		
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
				node.set_mountain_color(mountain_color)
				node.become_mountain(get_next_mountain_frame.call())
				# Assign mountain biome
				node.biome = biome_mountain
				nodes_made_mountains += 1
		
		elif roll == 2:
			# All except first and last
			if target_nodes.size() <= 2:
				debug_print("      → Skipped (need 3+ nodes, got %d)" % target_nodes.size())
				continue  # Need at least 3 nodes
			
			for i in range(1, target_nodes.size() - 1):
				target_nodes[i].is_mountain = true
				target_nodes[i].set_mountain_color(mountain_color)
				target_nodes[i].become_mountain(get_next_mountain_frame.call())
				# Assign mountain biome
				target_nodes[i].biome = biome_mountain
				nodes_made_mountains += 1
		
		elif roll == 3:
			# All except one random node
			if target_nodes.size() <= 1:
				debug_print("      → Skipped (need 2+ nodes, got %d)" % target_nodes.size())
				continue  # Need at least 2 nodes
			
			var exclude_idx = randi() % target_nodes.size()
			for i in range(target_nodes.size()):
				if i != exclude_idx:
					target_nodes[i].is_mountain = true
					target_nodes[i].set_mountain_color(mountain_color)
					target_nodes[i].become_mountain(get_next_mountain_frame.call())
					# Assign mountain biome
					target_nodes[i].biome = biome_mountain
					nodes_made_mountains += 1
		
		if nodes_made_mountains > 0:
			debug_print("      → Made %d nodes into mountains (from %d total in segment)" % [nodes_made_mountains, target_nodes.size()])
		mountains_created += nodes_made_mountains
	
	debug_print("  Total: Created %d mountain nodes from %d border nodes across %d border segments" % [mountains_created, border_nodes.size(), border_segments.size()])
	
	# Debug: Show sprite frame distribution
	if mountains_created > 0:
		var frame_distribution = "  Mountain sprite frame distribution: "
		for i in range(mountain_frame_count):
			frame_distribution += "f%d=%d " % [i, mountain_frame_usage[i]]
		debug_print(frame_distribution)

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
		debug_print("  No mountain nodes to center")
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
			debug_print("  Centering pass %d/%d complete" % [iteration + 1, iterations])
	
	debug_print("  Centered %d mountain nodes (%d iterations)" % [mountain_nodes.size(), iterations])

# ============================================================================
# STEP 12.6: DISCONNECT MOUNTAIN NODES
# ============================================================================

## Disconnect mountain-to-mountain connections (called BEFORE rivers)
## This allows rivers to start at mountains but prevents them from flowing through mountain ranges
func disconnect_inter_mountain_connections():
	var disconnected_count = 0
	
	for node in map_nodes:
		if node.is_mountain:
			# Remove ONLY connections to OTHER mountains
			for neighbor in node.connections.duplicate():
				if neighbor.is_mountain:
					# Both are mountains - disconnect this edge
					node.connections.erase(neighbor)
					neighbor.connections.erase(node)
					disconnected_count += 1
	
	debug_print("  Disconnected %d mountain-to-mountain connections" % (disconnected_count / 2))
	debug_print("  Mountains can still connect to non-mountain nodes (for river sources)")
	
	# Rebuild AStar graph to reflect new topology (no mountain-to-mountain paths)
	debug_print("  Rebuilding AStar graph with new mountain topology...")
	build_astar_graph()
	
	# Immediately disable ALL mountains in AStar (they'll be enabled temporarily per-river)
	debug_print("  Disabling all mountains in AStar (will enable per-source during river gen)...")
	for node in map_nodes:
		if node.is_mountain:
			astar.set_point_disabled(node.node_index, true)

## Disconnect ALL mountain connections (called AFTER rivers)
func disconnect_mountain_nodes():
	var disconnected_count = 0
	
	for node in map_nodes:
		if node.is_mountain:
			# Remove ALL remaining connections from this mountain node
			for neighbor in node.connections.duplicate():
				# Remove connection from both sides
				node.connections.erase(neighbor)
				neighbor.connections.erase(node)
				disconnected_count += 1
	
	debug_print("  Disconnected %d remaining mountain connections" % disconnected_count)
	# NOTE: AStar graph no longer rebuilt here - mountains disabled separately

## Disable mountain nodes in AStar2D pathfinding (called AFTER river generation)
func disable_mountains_in_astar():
	if not astar:
		debug_print("  WARNING: AStar not initialized")
		return
	
	var disabled_count = 0
	
	for node in map_nodes:
		if node.is_mountain:
			astar.set_point_disabled(node.node_index, true)
			disabled_count += 1
	
	debug_print("  Disabled %d mountain nodes in AStar2D (normal pathfinding will avoid them)" % disabled_count)

# ============================================================================
# STEP 12.7: ASSIGN BIOMES
# ============================================================================

## Load all biome resources
func _load_biome_resources():
	biome_forest = preload("res://resources/biomes/forest.tres")
	biome_plains = preload("res://resources/biomes/plains.tres")
	biome_swamp = preload("res://resources/biomes/swamp.tres")
	biome_mountain = preload("res://resources/biomes/mountain.tres")
	biome_badlands = preload("res://resources/biomes/badlands.tres")
	biome_ash_plains = preload("res://resources/biomes/ash_plains.tres")
	
	debug_print("  Loaded %d biome resources" % 6)

## Assign biomes to all nodes based on their properties
func assign_biomes():
	if map_nodes.size() == 0:
		return
	
	var biome_counts: Dictionary = {}
	
	# Map each region to a biome (region 0 = forest, region 1 = plains, etc.)
	var biomes_list = [biome_forest, biome_plains, biome_swamp, biome_badlands, biome_ash_plains]
	
	# Create region -> biome mapping
	var region_biome_map: Dictionary = {}
	for i in range(region_count):
		region_biome_map[i] = biomes_list[i % 5]
	
	for node in map_nodes:
		# Skip ALL mountains - they should already have mountain biome assigned
		if node.is_mountain:
			# Verify mountain has correct biome (should always be true now)
			if node.biome != biome_mountain:
				push_warning("Mountain node %d missing mountain biome, fixing..." % node.node_index)
				node.biome = biome_mountain
			biome_counts["mountain"] = biome_counts.get("mountain", 0) + 1
			continue
		
		# All nodes should have region_id now, use region's biome
		var assigned_biome = region_biome_map[node.region_id]
		
		node.biome = assigned_biome
		var biome_name = assigned_biome.biome_name if assigned_biome else "unknown"
		biome_counts[biome_name] = biome_counts.get(biome_name, 0) + 1
	
	# Print summary
	debug_print("  Biome assignment complete:")
	for biome_name in biome_counts:
		debug_print("    %s: %d nodes" % [biome_name, biome_counts[biome_name]])

# ============================================================================
# STEP 12.8: MAP FEATURE GENERATION
# ============================================================================

## Generate decorative features for the map based on biomes
func generate_map_features():
	map_features.clear()
	
	# Get landmass polygon for bounds checking
	var landmass_polygon = PackedVector2Array()
	if enable_landmass_shading and expanded_coast_lines.size() > 0:
		landmass_polygon = build_coast_polygon()
	
	# Build list of all connection lines for path avoidance
	var connection_lines: Array = []
	for node in map_nodes:
		var node_center = node.position + (node.size / 2.0)
		for neighbor in node.connections:
			var neighbor_center = neighbor.position + (neighbor.size / 2.0)
			# Avoid duplicates by only adding if this node has lower index
			if node.node_index < neighbor.node_index:
				connection_lines.append([node_center, neighbor_center])
	
	# Group nodes by biome
	var nodes_by_biome: Dictionary = {}
	for node in map_nodes:
		if node.biome == null:
			continue
		var biome_name = node.biome.biome_name
		if not nodes_by_biome.has(biome_name):
			nodes_by_biome[biome_name] = []
		nodes_by_biome[biome_name].append(node)
	
	# Generate features for each biome type
	var feature_counts: Dictionary = {}
	var removed_counts: Dictionary = {}
	for biome_name in nodes_by_biome:
		var biome_nodes = nodes_by_biome[biome_name]
		debug_print("  Processing biome '%s' with %d nodes" % [biome_name, biome_nodes.size()])
		var features = generate_features_for_biome(biome_name, biome_nodes, landmass_polygon, connection_lines)
		
		# Filter out features that are outside the landmass bounds
		var valid_features = []
		var removed_count = 0
		for feature in features:
			if feature.has("data") and feature.data.has("position"):
				var pos = feature.data.position
				if is_point_in_landmass(pos, landmass_polygon):
					valid_features.append(feature)
				else:
					removed_count += 1
			else:
				# Keep features without position data (shouldn't happen, but safe)
				valid_features.append(feature)
		
		map_features.append_array(valid_features)
		feature_counts[biome_name] = valid_features.size()
		removed_counts[biome_name] = removed_count
		
		if removed_count > 0:
			debug_print("  Biome '%s' generated %d features (%d removed outside landmass)" % [biome_name, valid_features.size(), removed_count])
		else:
			debug_print("  Biome '%s' generated %d features" % [biome_name, valid_features.size()])
	
	# Print summary
	var total_removed = 0
	for biome_name in removed_counts:
		total_removed += removed_counts[biome_name]
	
	if feature_debug_output:
		debug_print("  Feature generation complete:")
		for biome_name in feature_counts:
			debug_print("    %s: %d features" % [biome_name, feature_counts[biome_name]])
		if total_removed > 0:
			debug_print("  Total features: %d (%d removed outside landmass)" % [map_features.size(), total_removed])
		else:
			debug_print("  Total features: %d" % map_features.size())
	else:
		if total_removed > 0:
			debug_print("  Generated %d total features (%d removed outside landmass)" % [map_features.size(), total_removed])
		else:
			debug_print("  Generated %d total features" % map_features.size())

## Check if a position is too close to any connection line (path)
func is_too_close_to_path(pos: Vector2, connection_lines: Array, min_distance: float = 5.0) -> bool:
	for line in connection_lines:
		var line_start = line[0]
		var line_end = line[1]
		var closest_point = Geometry2D.get_closest_point_to_segment(pos, line_start, line_end)
		var distance = pos.distance_to(closest_point)
		if distance < min_distance:
			return true
	return false

## Check if a point is inside the landmass polygon
func is_point_in_landmass(point: Vector2, landmass_polygon: PackedVector2Array) -> bool:
	if landmass_polygon.size() < 3:
		return false  # Invalid polygon
	
	# Use Godot's built-in polygon point test
	return Geometry2D.is_point_in_polygon(point, landmass_polygon)

## Generate features for a specific biome type
func generate_features_for_biome(biome_name: String, biome_nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	match biome_name:
		"forest":
			return generate_forest_features(biome_nodes, landmass_polygon, connection_lines)
		"plains":
			return generate_plains_features(biome_nodes, landmass_polygon, connection_lines)
		"swamp":
			return generate_swamp_features(biome_nodes, landmass_polygon, connection_lines)
		"mountain":
			return generate_mountain_features(biome_nodes, landmass_polygon, connection_lines)
		"ash_plains":
			return generate_ash_plains_features(biome_nodes, landmass_polygon, connection_lines)
		"badlands":
			return generate_badlands_features(biome_nodes, landmass_polygon, connection_lines)
		_:
			return []

## Generate trees for forest biome - CONTIGUOUS REGION GRID PATTERN
func generate_forest_features(nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	var features = []
	var forest_radius = 25.0
	
	# Grid spacing - 2x lower density (3.6x instead of 1.8x)
	var avg_foliage_radius = 2.1
	var spacing_x = avg_foliage_radius * 2.88  # Horizontal spacing (20% tighter)
	var spacing_y = avg_foliage_radius * 3.6  # Vertical spacing
	
	# Find all contiguous forest regions
	var forest_nodes = []
	for node in nodes:
		if node.biome != null and node.biome.biome_name == "forest":
			forest_nodes.append(node)
	
	if forest_nodes.size() == 0:
		return features
	
	# Group forest nodes into connected regions
	var forest_regions = find_connected_regions(forest_nodes)
	
	# For each contiguous forest region, generate unified tree grid
	for region in forest_regions:
		if region.size() == 0:
			continue
		
		# Get bounding box of entire region
		var min_x = INF
		var max_x = -INF
		var min_y = INF
		var max_y = -INF
		
		var region_centers = []
		for node in region:
			var center = node.position + (node.size / 2.0)
			region_centers.append(center)
			min_x = min(min_x, center.x)
			max_x = max(max_x, center.x)
			min_y = min(min_y, center.y)
			max_y = max(max_y, center.y)
		
		# Expand bounds by forest radius
		var start_x = min_x - forest_radius
		var end_x = max_x + forest_radius
		var start_y = min_y - forest_radius
		var end_y = max_y + forest_radius
		
		# Generate grid across entire region
		var y = start_y
		while y <= end_y:
			var x = start_x
			# Offset every other row for honeycomb pattern
			var row = int((y - start_y) / spacing_y)
			if row % 2 == 1:
				x += spacing_x * 0.5
			
			while x <= end_x:
				var pos = Vector2(x, y)
				
				# Add jitter for organic look (more vertical variance)
				pos += Vector2(
					randf_range(-spacing_x * 0.15, spacing_x * 0.15),
					randf_range(-spacing_y * 0.35, spacing_y * 0.35)  # Increased vertical variance
				)
				
				# Check if within radius of ANY node in this region
				var near_forest = false
				for center in region_centers:
					if pos.distance_to(center) <= forest_radius:
						near_forest = true
						break
				
				if not near_forest:
					x += spacing_x
					continue
				
				features.append({
					"type": "tree",
					"biome": "forest",
					"data": {
						"position": pos,
						"vertical_stretch": 1.0 + randf_range(0.0, 1.0),
					"foliage_radius": randf_range(0.85, 1.275),  # 50% smaller
					"foliage_color": Color(0.75, 0.65, 0.50),  # Lighter brown/tan
					"trunk_color": Color(0.60, 0.45, 0.35),  # Lighter brown
					"trunk_width": 1.5,  # 25% thinner
					"trunk_length": randf_range(1.4375, 2.4375),  # 25% longer
					"outline_width": 1.0
					}
				})
				
				x += spacing_x
			y += spacing_y
	
	return features

## Find connected regions of nodes (flood fill algorithm)
func find_connected_regions(nodes: Array) -> Array:
	var regions = []
	var visited = {}
	
	for node in nodes:
		visited[node] = false
	
	for start_node in nodes:
		if visited[start_node]:
			continue
		
		# Start new region with flood fill
		var region = []
		var queue = [start_node]
		visited[start_node] = true
		
		while queue.size() > 0:
			var current = queue.pop_front()
			region.append(current)
			
			# Check all connections
			for neighbor in current.connections:
				if neighbor in nodes and not visited.get(neighbor, true):
					visited[neighbor] = true
					queue.append(neighbor)
		
		regions.append(region)
	
	return regions

## Generate trees for plains biome - DEAD SIMPLE, NO CHECKS
func generate_plains_features(nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	var features = []
	var plains_radius = 25.0
	var trees_per_node = 5
	
	# For each plains node, just place 5 trees around it - NO CHECKS
	for node in nodes:
		if node.biome == null or node.biome.biome_name != "plains":
			continue
		
		var node_center = node.position + (node.size / 2.0)
		
		for i in range(trees_per_node):
			# Random position within radius - NO VALIDATION
			var angle = randf() * TAU
			var distance = randf_range(0, plains_radius)
			var pos = node_center + Vector2(cos(angle), sin(angle)) * distance
			
			features.append({
				"type": "tree",
				"biome": "plains",
				"data": {
					"position": pos,
					"vertical_stretch": 1.0 + randf_range(0.1, 0.8),
				"foliage_radius": randf_range(0.85, 1.125),  # 50% smaller
			"foliage_color": Color(0.75, 0.65, 0.50),  # Lighter brown/tan
			"trunk_color": Color(0.60, 0.45, 0.35),  # Lighter brown
			"trunk_width": 1.5,  # 25% thinner
			"trunk_length": randf_range(1.4375, 2.125),  # 25% longer
			"outline_width": 1.0
				}
			})
	
	return features

## Generate scraggly trees for swamp biome - VERY SPARSE
func generate_swamp_features(nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	var features = []
	var swamp_radius = 25.0
	var trees_per_node = 2  # Very sparse
	
	for node in nodes:
		if node.biome == null or node.biome.biome_name != "swamp":
			continue
		
		var node_center = node.position + (node.size / 2.0)
		
		for i in range(trees_per_node):
			var angle = randf() * TAU
			var distance = randf_range(0, swamp_radius)
			var pos = node_center + Vector2(cos(angle), sin(angle)) * distance
			
			features.append({
				"type": "tree",
				"biome": "swamp",
				"data": {
					"position": pos,
					"vertical_stretch": 1.0 + randf_range(-0.2, 0.5),
				"foliage_radius": randf_range(0.575, 0.85),  # 50% smaller
			"foliage_color": Color(0.55, 0.50, 0.42),  # Lighter murky brown
			"trunk_color": Color(0.45, 0.40, 0.35),  # Lighter dark brown
			"trunk_width": 1.5,  # 25% thinner
			"trunk_length": randf_range(2.125, 3.5),  # 25% longer
			"outline_width": 1.0
				}
			})
	
	return features

## Generate trees around mountain nodes - RADIAL PLACEMENT
func generate_mountain_features(nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	var features = []
	var mountain_radius = 30.0
	var trees_per_mountain = 5  # Few trees around each mountain
	
	for node in nodes:
		if node.biome == null or node.biome.biome_name != "mountain":
			continue
		
		var node_center = node.position + (node.size / 2.0)
		
		for i in range(trees_per_mountain):
			var angle = (float(i) / float(trees_per_mountain)) * TAU + randf_range(-0.3, 0.3)
			var distance = randf_range(20, mountain_radius)
			var pos = node_center + Vector2(cos(angle), sin(angle)) * distance
			
			features.append({
				"type": "tree",
				"biome": "mountain",
				"data": {
					"position": pos,
					"vertical_stretch": 1.0 + randf_range(0.3, 0.8),
				"foliage_radius": randf_range(0.7, 0.975),  # 50% smaller
			"foliage_color": Color(0.70, 0.62, 0.48),  # Lighter tan
			"trunk_color": Color(0.55, 0.42, 0.32),  # Lighter brown
			"trunk_width": 1.5,  # 25% thinner
			"trunk_length": randf_range(1.4375, 2.125),  # 25% longer
			"outline_width": 1.0
				}
			})
	
	return features

## Generate NO trees for ash plains biome - BARREN
func generate_ash_plains_features(nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	return []  # Completely barren

## Generate dead/dying trees for badlands biome - VERY SPARSE
func generate_badlands_features(nodes: Array, landmass_polygon: PackedVector2Array, connection_lines: Array) -> Array:
	var features = []
	var badlands_radius = 25.0
	var trees_per_node = 2  # Very sparse
	
	for node in nodes:
		if node.biome == null or node.biome.biome_name != "badlands":
			continue
		
		var node_center = node.position + (node.size / 2.0)
		
		for i in range(trees_per_node):
			var angle = randf() * TAU
			var distance = randf_range(0, badlands_radius)
			var pos = node_center + Vector2(cos(angle), sin(angle)) * distance
			
			features.append({
				"type": "tree",
				"biome": "badlands",
				"data": {
					"position": pos,
					"vertical_stretch": 1.0 + randf_range(0.0, 0.3),
				"foliage_radius": randf_range(0.575, 0.8),  # 50% smaller
			"foliage_color": Color(0.65, 0.58, 0.50),  # Lighter grey-brown
			"trunk_color": Color(0.55, 0.48, 0.42),  # Lighter grey trunk
			"trunk_width": 1.5,  # 25% thinner
			"trunk_length": randf_range(1.0625, 1.75),  # 25% longer
			"outline_width": 1.0
				}
			})
	
	return features

# ============================================================================
# STEP 12.75: TOWN GENERATION
# ============================================================================

## Generate 0-2 towns per REGION (not biome type)
func generate_towns():
	town_nodes.clear()
	
	# Group nodes by region_id (exclude mountains and coastal nodes)
	var region_nodes: Dictionary = {}  # region_id -> Array[MapNode2D]
	
	for node in map_nodes:
		if node.is_mountain or node.is_coastal:
			continue
		if node.region_id < 0:
			continue
			
		if not region_nodes.has(node.region_id):
			region_nodes[node.region_id] = []
		region_nodes[node.region_id].append(node)
	
	# For each region, randomly assign 0-2 towns
	for region_id in region_nodes.keys():
		var nodes = region_nodes[region_id]
		if nodes.size() == 0:
			continue
		
		# Determine number of towns for this region
		var num_towns = _determine_town_count()
		
		# Sort nodes by distance from exit nodes (furthest first)
		var sorted_nodes = _sort_nodes_by_exit_distance(nodes, region_id)
		
		# Select nodes to be towns (with minimum distance constraints)
		var available_nodes = sorted_nodes.duplicate()
		var towns_created = []
		var attempts = 0
		var max_attempts = available_nodes.size() * 2  # Try twice as many times as there are nodes
		
		for i in range(num_towns):
			var found_valid_town = false
			
			while available_nodes.size() > 0 and attempts < max_attempts:
				attempts += 1
				
				# Try nodes in order (furthest from exits first)
				var candidate_node = available_nodes[0]
				
				# Check if this node is at least 5 steps away from all existing towns
				if _is_valid_town_location(candidate_node, 5):
					# Valid location - spawn town
					candidate_node.is_town = true
					candidate_node.node_type = MapNode2D.NodeType.TOWN
					town_nodes.append(candidate_node)
					towns_created.append(candidate_node.node_index)
					
					# Debug: show distance from nearest exit
					var exit_distance = _get_distance_to_nearest_exit(candidate_node, region_id)
					debug_print("TOWN: ✓ Placed town at node %d (exit distance: %d, attempts: %d)" % [candidate_node.node_index, exit_distance, attempts])
					
					found_valid_town = true
					available_nodes.remove_at(0)
					break
				else:
					# Too close to another town
					debug_print("TOWN: ✗ Node %d rejected (too close to existing town, exit distance was: %d)" % [candidate_node.node_index, _get_distance_to_nearest_exit(candidate_node, region_id)])
					available_nodes.remove_at(0)
			
			if not found_valid_town:
				debug_print("TOWN: Region %d: Could not place town %d (no valid locations with min distance)" % [region_id, i + 1])
				break
		
		# Get biome name for debug output
		var region_biome_name = "Unknown"
		if nodes.size() > 0 and nodes[0].biome != null:
			region_biome_name = nodes[0].biome.biome_name
		
		if towns_created.size() > 0:
			debug_print("TOWN: Region %d (%s): Generated %d towns at nodes %s" % [region_id, region_biome_name, towns_created.size(), str(towns_created)])
		else:
			debug_print("TOWN: Region %d (%s): No towns generated" % [region_id, region_biome_name])
	
	debug_print("TOWN: === Total towns generated: %d ===" % town_nodes.size())

## Determine how many towns a region should have (0-2, mostly 1)
func _determine_town_count() -> int:
	var roll = randf()
	if roll < 0.15:  # 15% chance of 0 towns
		return 0
	elif roll < 0.80:  # 65% chance of 1 town
		return 1
	else:  # 20% chance of 2 towns
		return 2

## Check if a node is a valid town location (far enough from existing towns)
func _is_valid_town_location(candidate: MapNode2D, min_distance: int) -> bool:
	if not astar:
		return true  # If no pathfinding, allow it
	
	# Check distance to all existing towns
	for existing_town in town_nodes:
		var path = astar.get_id_path(candidate.node_index, existing_town.node_index)
		var distance = path.size() - 1 if path.size() > 0 else 0
		
		if distance < min_distance:
			return false  # Too close to an existing town
	
	return true  # Far enough from all towns

## Get distance from a node to the nearest exit node in its region (for debug)
func _get_distance_to_nearest_exit(node: MapNode2D, region_id: int) -> int:
	if not astar:
		return -1
	
	var min_distance = 999
	for exit_node in map_nodes:
		if exit_node.region_id == region_id and exit_node.is_exit_node:
			var path = astar.get_id_path(node.node_index, exit_node.node_index)
			var distance = path.size() - 1 if path.size() > 0 else 999
			min_distance = mini(min_distance, distance)
	
	return min_distance


## Sort nodes by their minimum distance to any exit node (furthest first)
## This prioritizes placing towns away from region borders
func _sort_nodes_by_exit_distance(nodes: Array, region_id: int) -> Array:
	if not astar:
		return nodes  # No pathfinding, return as-is
	
	# Find all exit nodes in this region
	var exit_nodes_in_region: Array[MapNode2D] = []
	for node in map_nodes:
		if node.region_id == region_id and node.is_exit_node:
			exit_nodes_in_region.append(node)
	
	if exit_nodes_in_region.size() == 0:
		# No exits in this region, return nodes as-is
		debug_print("TOWN: Region %d: No exit nodes found (region has %d total nodes)" % [region_id, nodes.size()])
		return nodes
	
	debug_print("TOWN: Region %d: Found %d exit nodes, sorting %d candidate nodes by distance" % [region_id, exit_nodes_in_region.size(), nodes.size()])
	
	# Calculate minimum distance to any exit for each node
	var nodes_with_distances: Array = []
	for node in nodes:
		var min_exit_distance = INF
		
		# Find closest exit node
		for exit_node in exit_nodes_in_region:
			var path = astar.get_id_path(node.node_index, exit_node.node_index)
			var distance = path.size() - 1 if path.size() > 0 else 999
			min_exit_distance = mini(min_exit_distance, distance)
		
		nodes_with_distances.append([node, min_exit_distance])
	
	# Sort by distance (furthest from exits first)
	nodes_with_distances.sort_custom(func(a, b): return a[1] > b[1])
	
	# Debug: show distance range and sample
	if nodes_with_distances.size() > 0:
		var max_dist = nodes_with_distances[0][1]
		var min_dist = nodes_with_distances[nodes_with_distances.size() - 1][1]
		debug_print("TOWN: Region %d: Distance range: %d (furthest) to %d (closest)" % [region_id, max_dist, min_dist])
		
		# Show top 5 furthest nodes
		var sample_size = mini(5, nodes_with_distances.size())
		debug_print("TOWN: Top %d furthest nodes from exits:" % sample_size)
		for i in range(sample_size):
			var node = nodes_with_distances[i][0]
			var dist = nodes_with_distances[i][1]
			debug_print("TOWN:   Node %d: %d steps from exit" % [node.node_index, dist])
	
	# Extract just the nodes
	var sorted_nodes: Array = []
	for item in nodes_with_distances:
		sorted_nodes.append(item[0])
	
	return sorted_nodes

# ============================================================================
# STEP 12.77: EXIT NODE MARKING
# ============================================================================

## Mark nodes that connect to a different region as exit nodes
func mark_exit_nodes():
	var exit_node_count = 0
	
	for node in map_nodes:
		if node.is_mountain:
			continue
		if node.region_id < 0:
			continue
		
		node.is_exit_node = false
		
		# Check all connections
		for neighbor in node.connections:
			if neighbor.is_mountain:
				continue  # Mountains don't count as connections to other regions
			if neighbor.region_id < 0:
				continue
			
			# If neighbor has different region_id, this is an exit node
			if neighbor.region_id != node.region_id:
				node.is_exit_node = true
				exit_node_count += 1
				break
	
	debug_print("  Marked %d exit nodes" % exit_node_count)

# ============================================================================
# STEP 12.78: ASSIGN REGIONAL FOCAL POINTS
# ============================================================================

## Assign 1-2 focal points for each region (towns or central nodes)
func assign_region_focal_points():
	region_focal_points.clear()
	
	# Group nodes by region
	var region_nodes: Dictionary = {}
	for node in map_nodes:
		if node.is_mountain or node.is_coastal:
			continue
		if node.region_id < 0:
			continue
		
		if not region_nodes.has(node.region_id):
			region_nodes[node.region_id] = []
		region_nodes[node.region_id].append(node)
	
	# For each region, assign focal points
	for region_id in region_nodes.keys():
		var nodes = region_nodes[region_id]
		if nodes.size() == 0:
			continue
		
		var focal_points: Array[MapNode2D] = []
		
		# Check if this region has towns
		var region_towns: Array[MapNode2D] = []
		for node in nodes:
			if node.is_town:
				region_towns.append(node)
		
		if region_towns.size() > 0:
			# Use towns as focal points
			focal_points = region_towns
		else:
			# No towns - pick a central node
			var central_node = find_most_central_node(nodes)
			if central_node != null:
				focal_points.append(central_node)
		
		region_focal_points[region_id] = focal_points
		
		var biome_name = "Unknown"
		if nodes.size() > 0 and nodes[0].biome != null:
			biome_name = nodes[0].biome.biome_name
		
		var focal_indices = []
		for fp in focal_points:
			focal_indices.append(fp.node_index)
		
		debug_print("  Region %d (%s): %d focal points at nodes %s" % [region_id, biome_name, focal_points.size(), str(focal_indices)])
	
	debug_print("  Total regions with focal points: %d" % region_focal_points.size())

## Find the most central node in a set of nodes
func find_most_central_node(nodes: Array) -> MapNode2D:
	if nodes.size() == 0:
		return null
	
	# Calculate the center position of all nodes
	var center_pos = Vector2.ZERO
	for node in nodes:
		center_pos += node.position + (node.size / 2.0)
	center_pos /= nodes.size()
	
	# Find node closest to center
	var closest_node = null
	var min_distance = INF
	for node in nodes:
		var node_center = node.position + (node.size / 2.0)
		var distance = node_center.distance_to(center_pos)
		if distance < min_distance:
			min_distance = distance
			closest_node = node
	
	return closest_node

# ============================================================================
# STEP 12.79: ROAD GENERATION (SIMPLIFIED)
# ============================================================================

## Generate roads by connecting focal points of adjacent regions
func generate_roads():
	road_edges.clear()
	
	if region_focal_points.size() == 0:
		debug_print("  No focal points to connect")
		return
	
	# STEP 1: Connect focal points within each region (if multiple), respecting biome spawn rates
	debug_print("  Connecting focal points within regions...")
	for region_id in region_focal_points.keys():
		var focal_points = region_focal_points[region_id]
		
		# Check if this region can have roads based on biome
		if not regions.has(region_id):
			continue
		
		var region = regions[region_id]
		var spawn_rate = get_road_spawn_rate_for_biome(region.biome)
		
		# Skip if spawn rate is 0 or fails random check
		if spawn_rate <= 0.0:
			debug_print("    Region %d (biome: %s) has 0%% road spawn rate, skipping" % [region_id, region.biome.biome_name if region.biome else "NONE"])
			continue
		
		if randf() > spawn_rate:
			debug_print("    Region %d (biome: %s) failed road spawn rate check" % [region_id, region.biome.biome_name if region.biome else "NONE"])
			continue
		
		if focal_points.size() > 1:
			# Connect all focal points to each other
			for i in range(focal_points.size()):
				for j in range(i + 1, focal_points.size()):
					_create_road_path(focal_points[i], focal_points[j])
			debug_print("    Region %d (biome: %s, spawn rate: %.0f%%): Connected %d focal points" % [region_id, region.biome.biome_name if region.biome else "NONE", spawn_rate * 100, focal_points.size()])
	
	# STEP 2: Connect focal points across adjacent regions (respecting biome spawn rates)
	debug_print("  Connecting focal points across regions...")
	var region_pairs: Dictionary = {}
	var connections_made = 0
	
	for region_a_id in region_focal_points.keys():
		var focal_points_a = region_focal_points[region_a_id]
		
		# Check if region A can have roads
		if not regions.has(region_a_id):
			continue
		var region_a = regions[region_a_id]
		var spawn_rate_a = get_road_spawn_rate_for_biome(region_a.biome)
		if spawn_rate_a <= 0.0:
			continue
		
		# Find all adjacent regions
		var adjacent_regions = _find_adjacent_regions(region_a_id)
		
		for region_b_id in adjacent_regions:
			# Skip if already processed this pair
			var pair_key = _make_region_pair_key(region_a_id, region_b_id)
			if region_pairs.has(pair_key):
				continue
			region_pairs[pair_key] = true
			
			# Check if region B can have roads
			if not regions.has(region_b_id):
				continue
			var region_b = regions[region_b_id]
			var spawn_rate_b = get_road_spawn_rate_for_biome(region_b.biome)
			if spawn_rate_b <= 0.0:
				continue
			
			# Get focal points for region B
			if not region_focal_points.has(region_b_id):
				continue
			var focal_points_b = region_focal_points[region_b_id]
			
			# Calculate connection probability (average of both regions' spawn rates)
			var connection_rate = (spawn_rate_a + spawn_rate_b) / 2.0
			if randf() > connection_rate:
				debug_print("    Skipped connection between Region %d and %d (failed spawn rate check)" % [region_a_id, region_b_id])
				continue
			
			# Connect EVERY focal point in A to EVERY focal point in B
			for focal_a in focal_points_a:
				for focal_b in focal_points_b:
					_create_road_path(focal_a, focal_b)
					connections_made += 1
			
			debug_print("    Connected %d focal points in Region %d to %d focal points in Region %d" % [focal_points_a.size(), region_a_id, focal_points_b.size(), region_b_id])
	
	debug_print("  Total connections: %d" % connections_made)
	debug_print("  Total road edges: %d" % road_edges.size())

# ============================================================================
# STEP 12.795: COASTAL ROAD EXTENSIONS
# ============================================================================

## Extend dead-end roads toward the coast
func extend_deadends_to_coast():
	if not astar:
		debug_print("  Cannot extend roads - AStar not available")
		return
	
	# Find all dead-end nodes (nodes with exactly 1 road connection)
	var deadends: Array[MapNode2D] = []
	for node in map_nodes:
		if node.is_mountain or node.is_coastal:
			continue
		
		# Count road connections
		var road_connection_count = 0
		for neighbor in node.connections:
			if is_road(node, neighbor):
				road_connection_count += 1
		
		if road_connection_count == 1:
			deadends.append(node)
	
	debug_print("  Found %d dead-end nodes" % deadends.size())
	
	if deadends.size() == 0:
		return
	
	# Shuffle and take up to coastal_extension_count
	deadends.shuffle()
	var deadends_to_extend = mini(coastal_extension_count, deadends.size())
	
	var extensions_made = 0
	for i in range(deadends_to_extend):
		var deadend = deadends[i]
		
		# Check if this deadend's region has coastal nodes
		var coastal_nodes_in_region: Array[MapNode2D] = []
		for coastal_node in coastal_nodes:
			if coastal_node.region_id == deadend.region_id:
				coastal_nodes_in_region.append(coastal_node)
		
		if coastal_nodes_in_region.size() == 0:
			debug_print("    Deadend at node %d: No coastal nodes in region %d" % [deadend.node_index, deadend.region_id])
			continue
		
		# Find closest coastal node to this deadend
		var closest_coastal = null
		var min_distance = INF
		
		for coastal_node in coastal_nodes_in_region:
			var path = astar.get_id_path(deadend.node_index, coastal_node.node_index)
			var distance = path.size() - 1 if path.size() > 0 else 999
			if distance < min_distance:
				min_distance = distance
				closest_coastal = coastal_node
		
		if closest_coastal == null:
			debug_print("    Deadend at node %d: Could not find path to coast" % deadend.node_index)
			continue
		
		# Create road path from deadend to coast
		_create_road_path(deadend, closest_coastal)
		extensions_made += 1
		
		debug_print("    Extended deadend at node %d to coast node %d (%d steps)" % [deadend.node_index, closest_coastal.node_index, min_distance])
	
	debug_print("  Extended %d dead-end roads to coast" % extensions_made)
	debug_print("  Total road edges after extensions: %d" % road_edges.size())


# ============================================================================
# ROAD HELPER FUNCTIONS
# ============================================================================

## Find all regions adjacent to the given region
func _find_adjacent_regions(region_id: int) -> Array[int]:
	var adjacent: Array[int] = []
	
	# Look through all nodes in this region
	for node in map_nodes:
		if node.is_mountain:
			continue
		if node.region_id != region_id:
			continue
		
		# Check this node's neighbors for different regions
		for neighbor in node.connections:
			if neighbor.is_mountain:
				continue
			if neighbor.region_id < 0:
				continue
			
			if neighbor.region_id != region_id and neighbor.region_id not in adjacent:
				adjacent.append(neighbor.region_id)
	
	return adjacent

## Helper: Get road spawn rate for a given biome
func get_road_spawn_rate_for_biome(biome: Biome) -> float:
	if biome == null:
		return 0.5  # Default 50% for regions without biome
	
	# Match biome to spawn rate
	if biome == biome_forest:
		return road_spawn_rate_forest
	elif biome == biome_plains:
		return road_spawn_rate_plains
	elif biome == biome_swamp:
		return road_spawn_rate_swamp
	elif biome == biome_mountain:
		return road_spawn_rate_mountain
	elif biome == biome_badlands:
		return road_spawn_rate_badlands
	elif biome == biome_ash_plains:
		return road_spawn_rate_ash_plains
	else:
		return 0.5  # Unknown biome, default 50%

## Create a consistent key for a region pair (for tracking processed pairs)
func _make_region_pair_key(region_a: int, region_b: int) -> String:
	# Always put smaller ID first so "1_2" == "2_1"
	var min_id = mini(region_a, region_b)
	var max_id = maxi(region_a, region_b)
	return "%d_%d" % [min_id, max_id]

## Find the N closest nodes to a target node from a list
func _find_closest_nodes(target: MapNode2D, candidates: Array[MapNode2D], count: int) -> Array[MapNode2D]:
	if candidates.size() == 0:
		return []
	
	# Calculate distances and sort
	var distances: Array = []
	for candidate in candidates:
		var dist = target.position.distance_to(candidate.position)
		distances.append([candidate, dist])
	
	# Sort by distance
	distances.sort_custom(func(a, b): return a[1] < b[1])
	
	# Return top N
	var result: Array[MapNode2D] = []
	for i in range(mini(count, distances.size())):
		result.append(distances[i][0])
	return result

## Create a road path between two nodes using AStar pathfinding
func _create_road_path(from_node: MapNode2D, to_node: MapNode2D):
	if not astar:
		push_warning("AStar not initialized, cannot create road")
		return
	
	# Find path using AStar
	var path_ids = astar.get_id_path(from_node.node_index, to_node.node_index)
	
	if path_ids.size() < 2:
		return  # No valid path
	
	# Mark each edge in the path as a road
	for i in range(path_ids.size() - 1):
		var node_a_index = path_ids[i]
		var node_b_index = path_ids[i + 1]
		
		# Create edge key (smaller index first for consistency)
		var edge_key = _make_edge_key(node_a_index, node_b_index)
		road_edges[edge_key] = true

## Helper: Create consistent edge key from two node indices
func _make_edge_key(index_a: int, index_b: int) -> String:
	var min_idx = mini(index_a, index_b)
	var max_idx = maxi(index_a, index_b)
	return "%d_%d" % [min_idx, max_idx]

## Helper: Check if an edge is a road
func is_road(node_a: MapNode2D, node_b: MapNode2D) -> bool:
	var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
	return road_edges.has(edge_key)


# ============================================================================
# STEP 12.797: TRIANGLE CENTER IDENTIFICATION
# ============================================================================

## Identify all triangles in the graph and categorize by region ownership
func identify_triangle_centers():
	debug_print("TRIANGLES: === IDENTIFYING TRIANGLE CENTERS ===")
	
	# Clear existing data
	border_triangle_centers.clear()
	triple_border_triangle_centers.clear()
	for region in regions.values():
		region.triangle_centers.clear()
	
	var triangles_found: Dictionary = {}  # Track found triangles to avoid duplicates
	var internal_count = 0
	var border_count = 0
	var triple_border_count = 0
	
	# For each node, check all pairs of its neighbors
	for node in map_nodes:
		if node.connections.size() < 2:
			continue  # Need at least 2 neighbors to form a triangle
		
		# Check all pairs of neighbors
		for i in range(node.connections.size()):
			for j in range(i + 1, node.connections.size()):
				var neighbor_a = node.connections[i]
				var neighbor_b = node.connections[j]
				
				# Check if neighbor_a and neighbor_b are connected (forming a triangle)
				if neighbor_a.is_connected_to(neighbor_b):
					# Found a triangle: node, neighbor_a, neighbor_b
					# Create sorted key to avoid duplicates
					var indices = [node.node_index, neighbor_a.node_index, neighbor_b.node_index]
					indices.sort()
					var triangle_key = "%d_%d_%d" % [indices[0], indices[1], indices[2]]
					
					if triangles_found.has(triangle_key):
						continue  # Already processed this triangle
					triangles_found[triangle_key] = true
					
					# Calculate center of triangle
					var center = (node.position + neighbor_a.position + neighbor_b.position) / 3.0
					# Add half node size to get actual center in world space
					var node_offset = node.size / 2.0
					center += node_offset
					
					# Categorize by regions
					var region_ids = [node.region_id, neighbor_a.region_id, neighbor_b.region_id]
					var unique_regions: Array[int] = []
					for rid in region_ids:
						if rid >= 0 and rid not in unique_regions:
							unique_regions.append(rid)
					
					if unique_regions.size() == 1:
						# Internal triangle - belongs to single region
						if regions.has(unique_regions[0]):
							regions[unique_regions[0]].triangle_centers.append(center)
							internal_count += 1
					elif unique_regions.size() == 2:
						# Border triangle - spans 2 regions
						unique_regions.sort()
						border_triangle_centers.append({
							"center": center,
							"regions": unique_regions
						})
						border_count += 1
					elif unique_regions.size() == 3:
						# Triple border triangle - spans 3 regions
						unique_regions.sort()
						triple_border_triangle_centers.append({
							"center": center,
							"regions": unique_regions
						})
						triple_border_count += 1
	
	# Debug output
	debug_print("TRIANGLES: Found %d total triangles" % triangles_found.size())
	debug_print("TRIANGLES:   %d internal (single region)" % internal_count)
	debug_print("TRIANGLES:   %d border (2 regions)" % border_count)
	debug_print("TRIANGLES:   %d triple-border (3 regions)" % triple_border_count)
	
	# Per-region breakdown
	for region in regions.values():
		if region.triangle_centers.size() > 0:
			debug_print("TRIANGLES:   Region %d: %d internal triangles" % [region.region_id, region.triangle_centers.size()])
	
	debug_print("TRIANGLES: === TRIANGLE IDENTIFICATION COMPLETE ===")


# ============================================================================
# STEP 12.8: SECRET PATH IDENTIFICATION
# ============================================================================

## Identify paths that can be secret (not borders, not connected to towns)
## Called after generate_towns() and generate_roads()
func identify_secret_path_candidates():
	secret_edges.clear()
	debug_print("SECRET PATH: === IDENTIFYING SECRET PATH CANDIDATES ===")
	
	var candidate_count = 0
	var excluded_border = 0
	var excluded_town = 0
	var excluded_road = 0
	var total_edges = 0
	
	# Build set of town node indices for quick lookup
	var town_indices: Dictionary = {}
	for town in town_nodes:
		town_indices[town.node_index] = true
	
	# First pass: collect all candidate edges
	var candidates: Array = []
	
	# Iterate through all edges
	for node_a in map_nodes:
		if node_a.is_mountain:
			continue
			
		for node_b in node_a.connections:
			if node_b.is_mountain:
				continue
			
			# Only process each edge once
			if node_a.node_index >= node_b.node_index:
				continue
			
			total_edges += 1
			var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
			
			# EXCLUSION CRITERIA:
			
			# 1. Exclude border edges (exit paths)
			if border_edges.has(edge_key):
				excluded_border += 1
				continue
			
			# 2. Exclude paths connected to towns
			if town_indices.has(node_a.node_index) or town_indices.has(node_b.node_index):
				excluded_town += 1
				continue
			
			# 3. Exclude roads (roads should be visible)
			if road_edges.has(edge_key):
				excluded_road += 1
				continue
			
			# This edge is a candidate for being secret!
			candidates.append(edge_key)
			candidate_count += 1
	
	debug_print("SECRET PATH:   Total edges in graph: %d" % total_edges)
	debug_print("SECRET PATH:   Found %d secret path candidates" % candidate_count)
	debug_print("SECRET PATH:     Excluded %d border edges" % excluded_border)
	debug_print("SECRET PATH:     Excluded %d town-connected paths" % excluded_town)
	debug_print("SECRET PATH:     Excluded %d roads" % excluded_road)
	
	# Second pass: randomly select a subset of candidates to be secret (10-20%)
	# Ensure each node has at most 1 secret edge
	var secret_percentage = 0.15  # 15% of candidates become secret
	var max_secrets = max(int(candidate_count * secret_percentage), 2)  # At least 2 secrets if any candidates exist
	
	if candidates.size() == 0:
		debug_print("SECRET PATH:   No candidates available, no secret paths created")
		return
	
	# Shuffle candidates for random selection
	candidates.shuffle()
	
	# Track which nodes already have a secret edge
	var nodes_with_secrets: Dictionary = {}
	var secrets_created = 0
	var excluded_duplicate_node = 0
	
	# Iterate through shuffled candidates and add secrets, ensuring no node has more than 1
	for edge_key in candidates:
		if secrets_created >= max_secrets:
			break  # We've created enough secrets
		
		# Parse the edge key to get node indices
		var parts = edge_key.split("_")
		var node_a_idx = int(parts[0])
		var node_b_idx = int(parts[1])
		
		# Check if either node already has a secret edge
		if nodes_with_secrets.has(node_a_idx) or nodes_with_secrets.has(node_b_idx):
			excluded_duplicate_node += 1
			continue  # Skip this edge - one of the nodes already has a secret
		
		# Mark this edge as secret in the dictionary
		secret_edges[edge_key] = {
			"is_secret": true,
			"is_revealed": false
		}
		
		# Mark both nodes as having a secret edge (in dictionary and on node objects)
		nodes_with_secrets[node_a_idx] = true
		nodes_with_secrets[node_b_idx] = true
		
		# Set node properties to indicate they have secret paths
		var node_a = map_nodes[node_a_idx]
		var node_b = map_nodes[node_b_idx]
		node_a.has_secret_path = true
		node_b.has_secret_path = true
		node_a.secret_path_revealed = false
		node_b.secret_path_revealed = false
		
		secrets_created += 1
	
	debug_print("SECRET PATH:   Marked %d paths as secret (%.1f%% of candidates)" % [secret_edges.size(), (float(secret_edges.size()) / candidate_count) * 100.0])
	debug_print("SECRET PATH:     Excluded %d candidates (node already has secret)" % excluded_duplicate_node)

# ============================================================================
# SECRET PATH HELPER FUNCTIONS
# ============================================================================

## Check if edge is secret AND unrevealed
func is_edge_secret_and_hidden(node_a: MapNode2D, node_b: MapNode2D) -> bool:
	var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
	if not secret_edges.has(edge_key):
		return false
	var edge_data = secret_edges[edge_key]
	return edge_data.is_secret and not edge_data.is_revealed

## Check if edge is secret (regardless of reveal status)
func is_edge_secret(node_a: MapNode2D, node_b: MapNode2D) -> bool:
	var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
	return secret_edges.has(edge_key) and secret_edges[edge_key].is_secret

## Check if edge has been revealed
func is_edge_revealed(node_a: MapNode2D, node_b: MapNode2D) -> bool:
	var edge_key = _make_edge_key(node_a.node_index, node_b.node_index)
	if not secret_edges.has(edge_key):
		return false
	return secret_edges[edge_key].is_revealed

## Get the secret edge connected to a node (if any)
## Returns null if node has no secret edge, or the neighbor node if it does
func get_secret_neighbor(node: MapNode2D) -> MapNode2D:
	if not node or not node.has_secret_path:
		return null
	
	# Check all connections to find the secret one
	for neighbor in node.connections:
		if is_edge_secret(node, neighbor):
			return neighbor
	
	return null

## Check if a node has an unrevealed secret path
func node_has_unrevealed_secret(node: MapNode2D) -> bool:
	if not node:
		return false
	return node.has_secret_path and not node.secret_path_revealed

## Get all nodes that have secret paths
func get_nodes_with_secrets() -> Array[MapNode2D]:
	var result: Array[MapNode2D] = []
	for node in map_nodes:
		if node.has_secret_path:
			result.append(node)
	return result

## Get all nodes that have unrevealed secret paths
func get_nodes_with_unrevealed_secrets() -> Array[MapNode2D]:
	var result: Array[MapNode2D] = []
	for node in map_nodes:
		if node.has_secret_path and not node.secret_path_revealed:
			result.append(node)
	return result

## Get count of total secret edges in the map
func get_secret_edge_count() -> int:
	return secret_edges.size()

## Get count of unrevealed secret edges
func get_unrevealed_secret_count() -> int:
	var count = 0
	for edge_data in secret_edges.values():
		if edge_data.is_secret and not edge_data.is_revealed:
			count += 1
	return count

## Get count of revealed secret edges
func get_revealed_secret_count() -> int:
	var count = 0
	for edge_data in secret_edges.values():
		if edge_data.is_secret and edge_data.is_revealed:
			count += 1
	return count

## Get all secret edges as an array of [node_a, node_b] pairs
func get_all_secret_edges() -> Array:
	var result: Array = []
	for edge_key in secret_edges.keys():
		var parts = edge_key.split("_")
		var node_a_idx = int(parts[0])
		var node_b_idx = int(parts[1])
		var node_a = map_nodes[node_a_idx]
		var node_b = map_nodes[node_b_idx]
		result.append([node_a, node_b, secret_edges[edge_key]])
	return result

## Reveal all secret paths connected to a specific node
## Called by event effects when player discovers secrets
func reveal_secret_paths_at_node(node: MapNode2D):
	if not node:
		push_warning("SECRET PATH: Cannot reveal secrets at null node")
		return
	
	debug_print("SECRET PATH: === REVEALING SECRETS AT NODE %d ===" % node.node_index)
	debug_print("SECRET PATH:   Node has %d connections" % node.connections.size())
	debug_print("SECRET PATH:   Total secret edges in map: %d" % secret_edges.size())
	
	var revealed_count = 0
	var checked_count = 0
	
	# Check all connections from this node
	for neighbor in node.connections:
		checked_count += 1
		var edge_key = _make_edge_key(node.node_index, neighbor.node_index)
		debug_print("SECRET PATH:   Checking connection %d -> %d (key: %s)" % [node.node_index, neighbor.node_index, edge_key])
		
		# If this edge is a secret and hasn't been revealed
		if secret_edges.has(edge_key):
			var edge_data = secret_edges[edge_key]
			debug_print("SECRET PATH:     Edge IS in secret_edges: is_secret=%s, is_revealed=%s" % [edge_data.is_secret, edge_data.is_revealed])
			if edge_data.is_secret and not edge_data.is_revealed:
				# Reveal it in the dictionary!
				edge_data.is_revealed = true
				
				# Update node properties to reflect revelation
				node.secret_path_revealed = true
				neighbor.secret_path_revealed = true
				
				revealed_count += 1
				debug_print("SECRET PATH:     ✓ REVEALED secret path: %d <-> %d" % [node.node_index, neighbor.node_index])
			else:
				debug_print("SECRET PATH:     Already revealed or not secret")
		else:
			debug_print("SECRET PATH:     Edge NOT in secret_edges (normal path)")
	
	debug_print("SECRET PATH:   Checked %d connections, revealed %d secrets" % [checked_count, revealed_count])
	
	if revealed_count > 0:
		debug_print("SECRET PATH: ✓✓✓ Revealed %d secret paths at node %d" % [revealed_count, node.node_index])
		debug_print("SECRET PATH:   Calling update_node_visibility()...")
		# Update visibility to show newly revealed paths and nodes
		update_node_visibility()
		debug_print("SECRET PATH:   Calling queue_redraw()...")
		queue_redraw()
		debug_print("SECRET PATH:   Done!")
	else:
		debug_print("SECRET PATH: ✗ No secret paths to reveal at node %d" % node.node_index)

## Reveal ALL secret paths at current party location
func reveal_secret_paths_at_current_location():
	debug_print("SECRET PATH: reveal_secret_paths_at_current_location() called")
	if not current_party_node:
		push_warning("SECRET PATH: Cannot reveal secrets - no current party node")
		return
	
	debug_print("SECRET PATH: Current party node is: %d" % current_party_node.node_index)
	reveal_secret_paths_at_node(current_party_node)


# ============================================================================
# STEP 12.9: RIVER GENERATION
# ============================================================================

var river_id_counter: int = 0

## Main river generation function - Intelligent region-based system
func generate_rivers():
	rivers.clear()
	river_data.clear()
	river_id_counter = 0
	
	debug_print("RIVER: === GENERATING RIVERS (Region-Based System) ===")
	
	# Phase 1: Identify river sources (mountains on mountainous borders)
	var river_sources = identify_river_sources_intelligent()
	debug_print("RIVER:   Identified %d river sources" % river_sources.size())
	
	# Phase 1.5: Identify inter-region connections (non-mountainous borders)
	var inter_region_connections = identify_inter_region_connections()
	debug_print("RIVER:   Identified %d inter-region connections" % inter_region_connections.size())
	
	if river_sources.size() == 0 and inter_region_connections.size() == 0:
		debug_print("RIVER:   No river sources or connections found")
		return
	
	# Phase 2: Generate river paths from mountain sources
	generate_river_paths(river_sources)
	
	# Phase 3: Generate inter-region connector rivers
	generate_inter_region_rivers(inter_region_connections)
	
	# Phase 4: Mark all nodes that are part of river paths
	mark_river_nodes()
	
	# Count tributaries, main channels, connectors, and lakes
	var tributary_count = 0
	var main_channel_count = 0
	var connector_count = 0
	var lake_count = 0
	for river in rivers:
		var river_type = river.get("type", "")
		if river_type == "main_channel":
			main_channel_count += 1
		elif river_type == "inter_region_connector":
			connector_count += 1
		else:  # tributary
			tributary_count += 1
			if river.get("is_lake_river", false):
				lake_count += 1
	
	debug_print("RIVER: === RIVER GENERATION COMPLETE ===")
	debug_print("RIVER:   %d tributaries, %d main channels, %d inter-region connectors, %d lakes" % [tributary_count, main_channel_count, connector_count, lake_count])

## Mark all nodes that are part of river paths
func mark_river_nodes():
	debug_print("RIVER:   Marking nodes with rivers...")
	
	# First, clear all river flags
	for node in map_nodes:
		node.has_river = false
	
	var river_node_count = 0
	
	# Mark all nodes in river paths
	for river in rivers:
		if river.has("path") and river.path is Array:
			for path_node in river.path:
				if path_node is MapNode2D and not path_node.has_river:
					path_node.has_river = true
					river_node_count += 1
	
	debug_print("RIVER:     Marked %d nodes as river nodes" % river_node_count)

## Helper: Get river spawn rate for a given biome
func get_river_spawn_rate_for_biome(biome: Biome) -> float:
	if biome == null:
		return 0.5  # Default 50% for regions without biome
	
	# Match biome to spawn rate
	if biome == biome_forest:
		return river_spawn_rate_forest
	elif biome == biome_plains:
		return river_spawn_rate_plains
	elif biome == biome_swamp:
		return river_spawn_rate_swamp
	elif biome == biome_mountain:
		return river_spawn_rate_mountain
	elif biome == biome_badlands:
		return river_spawn_rate_badlands
	elif biome == biome_ash_plains:
		return river_spawn_rate_ash_plains
	else:
		return 0.5  # Unknown biome, default 50%

## Identify inter-region river connections (non-mountainous borders)
func identify_inter_region_connections() -> Array:
	var connections = []
	var processed_pairs: Dictionary = {}  # Track which region pairs we've already checked
	
	debug_print("RIVER:   Analyzing non-mountainous borders for inter-region connections...")
	
	for region_a in regions.values():
		# Skip if region A can't spawn rivers
		var spawn_rate_a = get_river_spawn_rate_for_biome(region_a.biome)
		if spawn_rate_a <= 0.0:
			continue
		
		for adjacent_id in region_a.adjacent_regions:
			# Create unique pair key (sorted so A-B and B-A are the same)
			var pair_key = ""
			if region_a.region_id < adjacent_id:
				pair_key = "%d_%d" % [region_a.region_id, adjacent_id]
			else:
				pair_key = "%d_%d" % [adjacent_id, region_a.region_id]
			
			# Skip if already processed this pair
			if processed_pairs.has(pair_key):
				continue
			processed_pairs[pair_key] = true
			
			var region_b = regions[adjacent_id]
			
			# Skip if region B can't spawn rivers
			var spawn_rate_b = get_river_spawn_rate_for_biome(region_b.biome)
			if spawn_rate_b <= 0.0:
				continue
			
			# Check if border is NON-mountainous
			if region_a.is_border_mountainous(adjacent_id):
				continue  # Skip mountainous borders
			
			# Roll chance for connection
			if randf() > inter_region_river_chance:
				continue
			
			# Determine which region is more interior (higher interiorness flows to lower)
			var source_region: Region
			var target_region: Region
			
			if region_a.average_interiorness > region_b.average_interiorness:
				source_region = region_a
				target_region = region_b
			else:
				source_region = region_b
				target_region = region_a
			
			# Get border nodes
			var border_nodes = region_a.get_border_with_region(adjacent_id)
			
			# Store connection data
			connections.append({
				"source_region": source_region,
				"target_region": target_region,
				"border_nodes": border_nodes
			})
			
			debug_print("RIVER:     Connection: Region %d (interior %.2f) -> Region %d (interior %.2f)" % [
				source_region.region_id,
				source_region.average_interiorness,
				target_region.region_id,
				target_region.average_interiorness
			])
	
	return connections

## Generate inter-region connector rivers
func generate_inter_region_rivers(connections: Array):
	if connections.size() == 0:
		return
	
	debug_print("RIVER:   Generating %d inter-region connector rivers..." % connections.size())
	
	for connection in connections:
		var source_region: Region = connection.source_region
		var target_region: Region = connection.target_region
		var border_nodes: Array = connection.border_nodes
		
		# Find best border crossing point (non-mountain, preferably central)
		var crossing_node = find_best_border_crossing(border_nodes)
		
		if crossing_node == null:
			debug_print("RIVER:     No valid crossing found for connection %d -> %d" % [source_region.region_id, target_region.region_id])
			continue
		
		# Path from source center to crossing point
		var path_to_border = astar.get_id_path(source_region.central_node.node_index, crossing_node.node_index)
		
		# Path from crossing point to target center
		var path_from_border = astar.get_id_path(crossing_node.node_index, target_region.central_node.node_index)
		
		if path_to_border.size() == 0 or path_from_border.size() == 0:
			debug_print("RIVER:     No valid path for connection %d -> %d" % [source_region.region_id, target_region.region_id])
			continue
		
		# Combine paths (avoid duplicate crossing node)
		var full_path: Array = []
		for node_idx in path_to_border:
			full_path.append(map_nodes[node_idx])
		for i in range(1, path_from_border.size()):  # Skip first (duplicate crossing)
			full_path.append(map_nodes[path_from_border[i]])
		
		# Convert to waypoints
		var waypoints: PackedVector2Array = PackedVector2Array()
		for i in range(full_path.size()):
			var path_node = full_path[i]
			var node_center = path_node.position + (path_node.size / 2.0)
			
			var is_first = (i == 0)
			var is_last = (i == full_path.size() - 1)
			
			# First node: use source region's randomized center
			if is_first:
				waypoints.append(source_region.randomized_center_position)
			# Last node: use target region's randomized center
			elif is_last:
				waypoints.append(target_region.randomized_center_position)
			# Add slight randomization to intermediate points
			elif river_waypoint_randomness > 0:
				var max_offset = poisson_min_distance * river_waypoint_randomness
				var rng = RandomNumberGenerator.new()
				rng.seed = (source_region.region_id * 10000 + target_region.region_id * 100 + i)
				var random_offset = Vector2(
					rng.randf_range(-max_offset, max_offset),
					rng.randf_range(-max_offset, max_offset)
				)
				waypoints.append(node_center + random_offset)
			else:
				waypoints.append(node_center)
		
		# Apply simplification passes
		if river_simplify_distance > 0:
			waypoints = simplify_river_waypoints(waypoints)
		waypoints = simplify_river_path_shortcuts(waypoints)
		
		# Add curvature to short rivers
		if waypoints.size() == 2:
			waypoints = add_curvature_to_short_rivers(waypoints, source_region.region_id * 100 + target_region.region_id)
		
		# Apply smoothing
		if river_curve_smoothness > 0:
			waypoints = smooth_river_waypoints(waypoints)
		
		# Apply noise
		if river_noise_amplitude > 0:
			waypoints = apply_river_noise(waypoints, float(source_region.region_id + target_region.region_id) * 50.0)
		
		# Calculate widths (constant width for connectors)
		var segment_widths: Array[float] = []
		for i in range(waypoints.size() - 1):
			segment_widths.append(river_end_width)  # Use end width (thinner)
		
		# Store river data
		var river_entry = {
			"id": river_id_counter,
			"type": "inter_region_connector",
			"source_region": source_region,
			"target_region": target_region,
			"path": full_path,
			"crossing_node": crossing_node,
			"is_lake_river": false,
			# Rendering data
			"segments": [{
				"type": "inter_region_connector",
				"waypoints": waypoints,
				"width": river_end_width,
				"segment_widths": segment_widths
			}],
			"lake_position": null,
			"lake_radius_x": 0,
			"lake_radius_y": 0
		}
		
		river_data.append(river_entry)
		source_region.rivers.append(river_entry)
		rivers.append(river_entry)
		river_id_counter += 1
		
		debug_print("RIVER:     ✓ Inter-region connector %d: Region %d -> %d (%d waypoints)" % [
			river_entry.id,
			source_region.region_id,
			target_region.region_id,
			waypoints.size()
		])

## Helper: Find best border crossing point for inter-region rivers
func find_best_border_crossing(border_nodes: Array) -> MapNode2D:
	# Filter to non-mountain nodes
	var valid_nodes: Array[MapNode2D] = []
	for node in border_nodes:
		if not node.is_mountain:
			valid_nodes.append(node)
	
	if valid_nodes.size() == 0:
		return null  # No valid crossing point
	
	# Pick middle node (spatially central)
	return valid_nodes[valid_nodes.size() / 2]

## Phase 1: Identify river sources - NEW INTELLIGENT SYSTEM
## One river per mountainous border (with biome-based spawn rates)
func identify_river_sources_intelligent() -> Array:
	var sources = []
	var used_sources: Dictionary = {}  # Track (mountain_node, target_region) pairs to prevent duplicates
	
	debug_print("RIVER:   Analyzing mountainous borders for river sources...")
	
	for region in regions.values():
		var mountainous_border_ids = region.get_mountainous_borders()
		
		if mountainous_border_ids.size() == 0:
			continue
		
		# Check biome and get spawn rate
		var spawn_rate = get_river_spawn_rate_for_biome(region.biome)
		
		# Skip this region entirely if spawn rate is 0
		if spawn_rate <= 0.0:
			debug_print("RIVER:     Region %d (biome: %s) has 0%% river spawn rate, skipping" % [region.region_id, region.biome.biome_name if region.biome else "NONE"])
			continue
		
		var landlocked_str = " (LANDLOCKED)" if region.is_landlocked else ""
		debug_print("RIVER:     Region %d has %d mountainous borders%s (biome: %s, spawn rate: %.0f%%)" % [region.region_id, mountainous_border_ids.size(), landlocked_str, region.biome.biome_name if region.biome else "NONE", spawn_rate * 100])
		
		# For each mountainous border, potentially spawn a river based on biome spawn rate
		for adjacent_id in mountainous_border_ids:
			# Random chance check based on biome spawn rate
			if randf() > spawn_rate:
				debug_print("RIVER:       Skipping border with region %d (failed spawn rate check)" % adjacent_id)
				continue
			
			var border_nodes_array = region.get_border_with_region(adjacent_id)
			
			# Get only the mountain nodes on this border
			var mountain_border_nodes: Array[MapNode2D] = []
			for border_node in border_nodes_array:
				if border_node.is_mountain:
					mountain_border_nodes.append(border_node)
			
			if mountain_border_nodes.size() == 0:
				debug_print("RIVER:       No mountain nodes found on border with region %d (this shouldn't happen!)" % adjacent_id)
				continue
			
			# Pick a random mountain node as the river source, but ensure uniqueness
			var source_node: MapNode2D = null
			var attempts = 0
			var max_attempts = mountain_border_nodes.size() * 2
			
			while attempts < max_attempts:
				var candidate = mountain_border_nodes[randi() % mountain_border_nodes.size()]
				var key = "%d_%d" % [candidate.node_index, region.region_id]
				
				# Check if this (mountain, region) pair has already been used
				if not used_sources.has(key):
					source_node = candidate
					used_sources[key] = true
					break
				
				attempts += 1
			
			# If we couldn't find a unique source, skip this river
			if source_node == null:
				debug_print("RIVER:       Could not find unique mountain source on border with region %d (all mountains already used)" % adjacent_id)
				continue
			
			sources.append({
				"source_node": source_node,
				"region": region,
				"border_with": adjacent_id,
				"id": river_id_counter
			})
			
			debug_print("RIVER:       River %d: Source at node %d (border with region %d)" % [river_id_counter, source_node.node_index, adjacent_id])
			river_id_counter += 1
	
	return sources

## Phase 2: Generate river paths from sources
func generate_river_paths(river_sources: Array):
	var regions_needing_main_channel: Dictionary = {}  # Track regions that need center-to-coast channel
	var tributaries: Array = []  # Store individual source-to-center rivers
	
	# PHASE 1: Generate tributary paths (source to center only)
	for source_data in river_sources:
		var source_node: MapNode2D = source_data.source_node
		var region: Region = source_data.region
		var river_id: int = source_data.id
		
		debug_print("RIVER:   Generating tributary %d from node %d" % [river_id, source_node.node_index])
		
		var river_path: Array = []
		
		# STEP 1: Path from mountain source toward regional center ONLY
		if region.central_node == null:
			debug_print("RIVER:     WARNING: Region %d has no central node, skipping tributary" % region.region_id)
			continue
		
		var center_node = region.central_node
		
		# Temporarily enable ONLY this source mountain for pathfinding
		if source_node.is_mountain:
			astar.set_point_disabled(source_node.node_index, false)
		
		var path_to_center = astar.get_id_path(source_node.node_index, center_node.node_index)
		
		# Disable the source mountain again
		if source_node.is_mountain:
			astar.set_point_disabled(source_node.node_index, true)
		
		if path_to_center.size() == 0:
			debug_print("RIVER:     ✗ REJECTED: No path from source node %d to center node %d" % [source_node.node_index, center_node.node_index])
			continue
		
		# Convert node indices to node references and validate path
		var hit_coast_early = false
		var path_invalid = false
		
		for i in range(path_to_center.size()):
			var node_idx = path_to_center[i]
			var path_node = map_nodes[node_idx]
			
			# VALIDATION: Ensure we don't pass through OTHER mountains (only source is allowed)
			if path_node.is_mountain and i > 0:
				debug_print("RIVER:     ERROR: Path goes through mountain node %d (not the source!)" % path_node.node_index)
				path_invalid = true
				break
			
			river_path.append(path_node)
			
			# Check if we hit a coastal node before reaching center
			if river_path.size() > 1 and path_node.is_coastal:
				hit_coast_early = true
				debug_print("RIVER:     Hit coast early at node %d (tributary complete)" % path_node.node_index)
				break
		
		# Skip this tributary if path is invalid
		if path_invalid:
			debug_print("RIVER:     ✗ REJECTED Tributary %d - path through mountains detected" % river_id)
			continue
		
		debug_print("RIVER:     Tributary path: %d nodes" % river_path.size())
		
		# Store tributary data
		tributaries.append({
			"id": river_id,
			"source_node": source_node,
			"path": river_path,
			"region": region,
			"hit_coast_early": hit_coast_early
		})
		
		# Mark this region as needing a main channel (unless tributary already hit coast)
		if not hit_coast_early and not region.is_landlocked:
			regions_needing_main_channel[region.region_id] = region
	
	# PHASE 2: Generate main channels (center to coast, ONE per region)
	var main_channels: Array = []
	for region_id in regions_needing_main_channel.keys():
		var region: Region = regions_needing_main_channel[region_id]
		var center_node = region.central_node
		
		debug_print("RIVER:   Generating main channel for region %d from center node %d" % [region.region_id, center_node.node_index])
		
		var target_coastal = find_central_coastal_node_in_region(region)
		if target_coastal == null:
			debug_print("RIVER:     ✗ Could not find coastal node in region %d, skipping main channel" % region.region_id)
			continue
		
		# Check if center is already coastal
		if center_node == target_coastal:
			debug_print("RIVER:     Center is already coastal, no main channel needed")
			continue
		
		var path_to_coast = astar.get_id_path(center_node.node_index, target_coastal.node_index)
		
		if path_to_coast.size() == 0:
			debug_print("RIVER:     WARNING: No path from center %d to coast %d" % [center_node.node_index, target_coastal.node_index])
			continue
		
		# Build and validate path
		var channel_path: Array = []
		var path_invalid = false
		for i in range(path_to_coast.size()):
			var path_node = map_nodes[path_to_coast[i]]
			
			# VALIDATION: Ensure we don't pass through mountains
			if path_node.is_mountain:
				debug_print("RIVER:     ERROR: Main channel goes through mountain node %d!" % path_node.node_index)
				path_invalid = true
				break
			
			channel_path.append(path_node)
		
		if path_invalid:
			debug_print("RIVER:     ✗ REJECTED main channel for region %d" % region.region_id)
			continue
		
		debug_print("RIVER:     Main channel: %d nodes" % channel_path.size())
		
		# Store main channel
		main_channels.append({
			"type": "main_channel",
			"region": region,
			"path": channel_path
		})
	
	# PHASE 3: Convert tributaries to renderable format
	for tributary_data in tributaries:
		var river_path = tributary_data.path
		var region = tributary_data.region
		var river_id = tributary_data.id
		var trib_source_node = tributary_data.source_node
		var center_node = region.central_node
		var hit_coast_early = tributary_data.hit_coast_early
		
		# Convert path (nodes) to waypoints (positions) for rendering
		var waypoints: PackedVector2Array = PackedVector2Array()
		
		for i in range(river_path.size()):
			var path_node = river_path[i]
			var node_center = path_node.position + (path_node.size / 2.0)
			
			# Identify key points that should NOT be randomized
			var is_first = (i == 0)
			var is_last = (i == river_path.size() - 1)
			var is_center = (path_node == center_node)
			var is_key_point = is_first or is_last or is_center
			
			# Special case: if this is the LAST node AND it's coastal (hit coast early), use expanded coast position
			if is_last and path_node.is_coastal:
				if expanded_coast_positions.has(path_node.node_index):
					var expanded_pos = expanded_coast_positions[path_node.node_index]
					waypoints.append(expanded_pos)
					debug_print("RIVER:     Tributary extended to expanded coast position")
				else:
					waypoints.append(node_center)
			# Special case: if this is the CENTRAL node, use the pre-calculated randomized center for the region
			elif is_center:
				waypoints.append(region.randomized_center_position)
			# Intermediate points: add randomization (seeded for consistency)
			elif not is_key_point and river_waypoint_randomness > 0:
				var max_offset = poisson_min_distance * river_waypoint_randomness
				# Use deterministic seed based on river_id and node index
				var rng = RandomNumberGenerator.new()
				rng.seed = (river_id * 1000 + i)
				var random_offset = Vector2(
					rng.randf_range(-max_offset, max_offset),
					rng.randf_range(-max_offset, max_offset)
				)
				waypoints.append(node_center + random_offset)
			else:
				waypoints.append(node_center)
		
		# Simplify path by merging nearby waypoints (before smoothing)
		if river_simplify_distance > 0:
			waypoints = simplify_river_waypoints(waypoints)
		
		# Simplify path by removing zigzags (shortcut to closer downstream points)
		waypoints = simplify_river_path_shortcuts(waypoints)
		
		# Add curvature to short rivers (2 waypoints only)
		if waypoints.size() == 2:
			waypoints = add_curvature_to_short_rivers(waypoints, river_id)
		
		# Apply curve smoothing to create flowing rivers
		if river_curve_smoothness > 0:
			waypoints = smooth_river_waypoints(waypoints)
		
		# Apply noise for natural wiggling (use river_id as seed for variation)
		if river_noise_amplitude > 0:
			waypoints = apply_river_noise(waypoints, float(river_id) * 10.0)
		
		# Calculate tapered widths (source wide, end narrow)
		var segment_widths: Array[float] = []
		for i in range(waypoints.size() - 1):
			var t = float(i) / float(max(1, waypoints.size() - 2))  # 0.0 at source, 1.0 at end
			var width = lerp(river_source_width, river_end_width, t)
			segment_widths.append(width)
		
		# Store tributary data
		var river_entry = {
			"id": river_id,
			"type": "tributary",
			"source_node": trib_source_node,
			"path": river_path,
			"region": region,
			"is_lake_river": region.is_landlocked and hit_coast_early == false,
			# Rendering data
			"segments": [{
				"type": "main_channel",
				"waypoints": waypoints,
				"width": river_source_width,
				"segment_widths": segment_widths
			}],
			# Lake data (if landlocked and didn't hit coast)
			"lake_position": waypoints[-1] if (region.is_landlocked and not hit_coast_early and waypoints.size() > 0) else null,
			"lake_radius_x": lake_radius_x,
			"lake_radius_y": lake_radius_y
		}
		
		# Debug lake data
		if region.is_landlocked and not hit_coast_early and waypoints.size() > 0:
			debug_print("RIVER:     Tributary ends at lake: position=%s, radius_x=%.1f, radius_y=%.1f" % [waypoints[-1], lake_radius_x, lake_radius_y])
		
		river_data.append(river_entry)
		region.rivers.append(river_entry)
		rivers.append(river_entry)
		
		debug_print("RIVER:     ✓ Tributary %d complete: %d nodes, %d waypoints" % [river_id, river_path.size(), waypoints.size()])
	
	# PHASE 4: Convert main channels to renderable format
	for channel_data in main_channels:
		var channel_path = channel_data.path
		var region = channel_data.region
		var center_node = region.central_node
		
		# Convert path to waypoints
		var waypoints: PackedVector2Array = PackedVector2Array()
		for i in range(channel_path.size()):
			var path_node = channel_path[i]
			var node_center = path_node.position + (path_node.size / 2.0)
			
			var is_first = (i == 0)
			var is_last = (i == channel_path.size() - 1)
			var is_key_point = is_first or is_last
			
			# First node should use randomized center position
			if is_first and path_node == center_node:
				waypoints.append(region.randomized_center_position)
			# Last node (coastal) should use expanded coast position
			elif is_last and path_node.is_coastal:
				if expanded_coast_positions.has(path_node.node_index):
					waypoints.append(expanded_coast_positions[path_node.node_index])
					debug_print("RIVER:     Main channel extended to expanded coast")
				else:
					waypoints.append(node_center)
			# Intermediate points: add randomization (seeded for consistency)
			elif not is_key_point and river_waypoint_randomness > 0:
				var max_offset = poisson_min_distance * river_waypoint_randomness
				# Use deterministic seed based on region_id and node index
				var rng = RandomNumberGenerator.new()
				rng.seed = (region.region_id * 10000 + i)
				var random_offset = Vector2(
					rng.randf_range(-max_offset, max_offset),
					rng.randf_range(-max_offset, max_offset)
				)
				waypoints.append(node_center + random_offset)
			else:
				waypoints.append(node_center)
		
		# Simplify path by merging nearby waypoints (before smoothing)
		if river_simplify_distance > 0:
			waypoints = simplify_river_waypoints(waypoints)
		
		# Simplify path by removing zigzags (shortcut to closer downstream points)
		waypoints = simplify_river_path_shortcuts(waypoints)
		
		# Add curvature to short rivers (2 waypoints only)
		if waypoints.size() == 2:
			waypoints = add_curvature_to_short_rivers(waypoints, region.region_id * 1000)
		
		# Apply curve smoothing
		if river_curve_smoothness > 0:
			waypoints = smooth_river_waypoints(waypoints)
		
		# Apply noise for natural wiggling (use region_id as seed for consistent main channel)
		if river_noise_amplitude > 0:
			waypoints = apply_river_noise(waypoints, float(region.region_id) * 100.0)
		
		# Calculate tapered widths (maintain end width through main channel)
		var segment_widths: Array[float] = []
		for i in range(waypoints.size() - 1):
			segment_widths.append(river_end_width)  # Main channel stays at end width
		
		# Store main channel data
		var channel_entry = {
			"id": -1,  # Main channels don't get individual IDs
			"type": "main_channel",
			"path": channel_path,
			"region": region,
			"is_lake_river": false,
			# Rendering data
			"segments": [{
				"type": "main_channel",
				"waypoints": waypoints,
				"width": river_end_width,
				"segment_widths": segment_widths
			}],
			"lake_position": null,
			"lake_radius_x": 0,
			"lake_radius_y": 0
		}
		
		river_data.append(channel_entry)
		region.rivers.append(channel_entry)
		rivers.append(channel_entry)
		
		debug_print("RIVER:     ✓ Main channel complete for region %d: %d nodes, %d waypoints" % [region.region_id, channel_path.size(), waypoints.size()])
	
	# Summary
	debug_print("RIVER: Generated %d tributaries and %d main channels from %d sources" % [tributaries.size(), main_channels.size(), river_sources.size()])

## Helper: Simplify river waypoints by merging nearby points
func simplify_river_waypoints(waypoints: PackedVector2Array) -> PackedVector2Array:
	if waypoints.size() < 2 or river_simplify_distance <= 0.0:
		return waypoints  # Not enough points or simplification disabled
	
	var simplified: PackedVector2Array = PackedVector2Array()
	var threshold_sq = river_simplify_distance * river_simplify_distance  # Use squared distance for faster comparison
	
	# Always keep the first point
	simplified.append(waypoints[0])
	
	# Process remaining points
	for i in range(1, waypoints.size()):
		var current_point = waypoints[i]
		var should_add = true
		
		# Check if this point is too close to the last added point
		if simplified.size() > 0:
			var last_point = simplified[simplified.size() - 1]
			var dist_sq = current_point.distance_squared_to(last_point)
			
			if dist_sq < threshold_sq:
				# Too close - skip this point (or merge it with the last one)
				should_add = false
				
				# Special handling: if this is the last point, we still want to keep it
				# So we replace the previous point with an average
				if i == waypoints.size() - 1:
					var merged = (last_point + current_point) / 2.0
					simplified[simplified.size() - 1] = merged
		
		if should_add:
			simplified.append(current_point)
	
	return simplified

## Helper: Simplify river path by removing unnecessary zigzags (shortcut to closer downstream points)
func simplify_river_path_shortcuts(waypoints: PackedVector2Array) -> PackedVector2Array:
	if waypoints.size() < 3:
		return waypoints  # Need at least 3 points to create shortcuts
	
	var simplified: PackedVector2Array = PackedVector2Array()
	var current_idx = 0
	
	while current_idx < waypoints.size():
		var current_point = waypoints[current_idx]
		simplified.append(current_point)
		
		# If this is the last point, we're done
		if current_idx >= waypoints.size() - 1:
			break
		
		# Check if any point further down the path is closer than the immediate next point
		var next_idx = current_idx + 1
		var next_point = waypoints[next_idx]
		var next_dist = current_point.distance_to(next_point)
		
		var best_jump_idx = next_idx
		var best_jump_dist = next_dist
		
		# Check all points at least 2 positions ahead (skip immediate neighbor)
		for check_idx in range(current_idx + 2, waypoints.size()):
			var check_point = waypoints[check_idx]
			var check_dist = current_point.distance_to(check_point)
			
			# If this point is closer, it's a potential shortcut
			if check_dist < best_jump_dist:
				best_jump_idx = check_idx
				best_jump_dist = check_dist
		
		# Jump to the closest reachable point (could be immediate neighbor or a shortcut)
		current_idx = best_jump_idx
	
	return simplified

## Helper: Add curvature to short river segments (2 waypoints) by inserting intermediate points
func add_curvature_to_short_rivers(waypoints: PackedVector2Array, seed: int = 0) -> PackedVector2Array:
	if waypoints.size() != 2:
		return waypoints  # Only process rivers with exactly 2 waypoints
	
	var start = waypoints[0]
	var end = waypoints[1]
	var curved: PackedVector2Array = PackedVector2Array()
	
	# Calculate direction and perpendicular
	var direction = (end - start).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)  # Rotate 90 degrees
	var distance = start.distance_to(end)
	
	# Use seed for consistent randomization
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	# Add start point
	curved.append(start)
	
	# Add 1-2 intermediate points with perpendicular offset for curvature
	var num_intermediate = 2  # Add 2 points for a nice curve
	
	for i in range(1, num_intermediate + 1):
		var t = float(i) / float(num_intermediate + 1)
		var midpoint = start.lerp(end, t)
		
		# Add perpendicular offset (largest in the middle, tapering toward ends)
		var curve_strength = sin(t * PI)  # 0 at ends, 1.0 at middle
		var max_offset = distance * 0.15  # 15% of river length
		var random_side = rng.randf_range(-1.0, 1.0)  # Random direction
		var offset = perpendicular * random_side * max_offset * curve_strength
		
		curved.append(midpoint + offset)
	
	# Add end point
	curved.append(end)
	
	return curved

## Helper: Generate smooth Catmull-Rom spline through waypoints
func smooth_river_waypoints(waypoints: PackedVector2Array) -> PackedVector2Array:
	if waypoints.size() < 3 or river_curve_smoothness < 1:
		return waypoints  # Not enough points to smooth or smoothing disabled
	
	var smoothed: PackedVector2Array = PackedVector2Array()
	
	# Add first point as-is
	smoothed.append(waypoints[0])
	
	# Interpolate between each pair of waypoints
	for i in range(waypoints.size() - 1):
		var p0 = waypoints[max(0, i - 1)]          # Previous point (or current if first)
		var p1 = waypoints[i]                       # Current start point
		var p2 = waypoints[i + 1]                   # Current end point
		var p3 = waypoints[min(waypoints.size() - 1, i + 2)]  # Next point (or current end if last)
		
		# Generate interpolated points along the curve
		for j in range(river_curve_smoothness):
			var t = float(j) / float(river_curve_smoothness)
			var point = catmull_rom_point(p0, p1, p2, p3, t)
			smoothed.append(point)
	
	# Add final point
	smoothed.append(waypoints[waypoints.size() - 1])
	
	return smoothed

## Helper: Calculate a point on a Catmull-Rom spline
func catmull_rom_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 = t * t
	var t3 = t2 * t
	
	# Catmull-Rom basis functions
	var v0 = -0.5 * t3 + t2 - 0.5 * t
	var v1 = 1.5 * t3 - 2.5 * t2 + 1.0
	var v2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t
	var v3 = 0.5 * t3 - 0.5 * t2
	
	return p0 * v0 + p1 * v1 + p2 * v2 + p3 * v3

## Helper: Apply perpendicular noise to river waypoints for natural wiggling
func apply_river_noise(waypoints: PackedVector2Array, seed_offset: float = 0.0) -> PackedVector2Array:
	if waypoints.size() < 2 or river_noise_amplitude <= 0.0:
		return waypoints  # Not enough points or noise disabled
	
	var noisy_waypoints: PackedVector2Array = PackedVector2Array()
	var accumulated_distance: float = 0.0
	
	for i in range(waypoints.size()):
		var current = waypoints[i]
		
		# Keep first and last points fixed to preserve connections
		if i == 0 or i == waypoints.size() - 1:
			noisy_waypoints.append(current)
			if i < waypoints.size() - 1:
				accumulated_distance += current.distance_to(waypoints[i + 1])
			continue
		
		# Calculate direction perpendicular to river flow
		var prev = waypoints[i - 1]
		var next = waypoints[i + 1]
		var direction = (next - prev).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)  # Rotate 90 degrees
		
		# Calculate noise value using accumulated distance along path
		var noise_input = accumulated_distance * river_noise_frequency + seed_offset
		var noise_value = sin(noise_input) * cos(noise_input * 1.7)  # Combine two frequencies for more organic look
		
		# Apply noise perpendicular to flow direction
		var offset = perpendicular * noise_value * river_noise_amplitude
		noisy_waypoints.append(current + offset)
		
		# Accumulate distance for next iteration
		if i < waypoints.size() - 1:
			accumulated_distance += current.distance_to(waypoints[i + 1])
	
	return noisy_waypoints

## Helper: Find the central coastal node in a region (middle of the coastal array)
func find_central_coastal_node_in_region(region: Region) -> MapNode2D:
	if region.coastal_nodes.size() == 0:
		debug_print("RIVER:       No coastal nodes in region %d" % region.region_id)
		return null
	
	# Filter to only nodes actually in this region
	var region_coastal_nodes: Array[MapNode2D] = []
	for coastal_node in region.coastal_nodes:
		if coastal_node.region_id == region.region_id:
			region_coastal_nodes.append(coastal_node)
	
	if region_coastal_nodes.size() == 0:
		debug_print("RIVER:       No coastal nodes found in region %d after filtering" % region.region_id)
		return null
	
	# Pick the middle node in the array
	var middle_index = region_coastal_nodes.size() / 2
	var central_coastal = region_coastal_nodes[middle_index]
	
	debug_print("RIVER:       Selected central coastal node %d (index %d of %d coastal nodes)" % [
		central_coastal.node_index,
		middle_index,
		region_coastal_nodes.size()
	])
	
	return central_coastal

## Intelligent meandering pathfinding: moves toward coast by decreasing interiorness least
## At each step, picks the neighbor that decreases interiorness the LEAST (stays inland longest)
func find_meandering_path_to_coast(start_node: MapNode2D, region: Region) -> Array[MapNode2D]:
	var path: Array[MapNode2D] = [start_node]
	var current_node = start_node
	var visited: Dictionary = {start_node.node_index: true}
	var max_steps = 100  # Safety limit to prevent infinite loops
	var steps = 0
	
	debug_print("RIVER:       Meandering pathfinding from node %d (interiorness: %.2f)" % [current_node.node_index, current_node.graph_interiorness_score])
	
	# Special case: if starting node is already coastal, we're done
	if current_node.is_coastal:
		debug_print("RIVER:       Start node is already coastal, path complete")
		return path
	
	while not current_node.is_coastal and steps < max_steps:
		steps += 1
		
		# Find all valid neighbors (connected, in same region, not visited, not mountains)
		var valid_neighbors: Array = []
		for neighbor in current_node.connections:
			if neighbor.is_mountain:
				continue
			# Allow moving to adjacent regions if headed toward coast
			# (rivers can flow between regions naturally)
			if visited.has(neighbor.node_index):
				continue
			
			# Calculate interiorness change
			var current_interiorness = current_node.graph_interiorness_score
			var neighbor_interiorness = neighbor.graph_interiorness_score
			var delta = neighbor_interiorness - current_interiorness
			
			# MUST decrease interiorness (move toward coast)
			# But pick the one that decreases LEAST (meanders)
			if delta < 0:  # Strict decrease required
				valid_neighbors.append({
					"node": neighbor,
					"delta": delta
				})
		
		if valid_neighbors.size() == 0:
			# No valid moves that decrease interiorness
			# As fallback, allow ANY non-visited neighbor (desperation move)
			debug_print("RIVER:         No decreasing neighbors, trying any neighbor...")
			for neighbor in current_node.connections:
				if neighbor.is_mountain:
					continue
				if visited.has(neighbor.node_index):
					continue
				
				var delta = neighbor.graph_interiorness_score - current_node.graph_interiorness_score
				valid_neighbors.append({
					"node": neighbor,
					"delta": delta
				})
			
			if valid_neighbors.size() == 0:
				debug_print("RIVER:       Stuck at node %d (no unvisited neighbors)" % current_node.node_index)
				break
		
		# Sort by delta (ascending) - pick the SMALLEST decrease (stay interior longest)
		# Or if all increase, pick smallest increase
		valid_neighbors.sort_custom(func(a, b): return a.delta < b.delta)
		
		# Pick the neighbor with smallest change
		var best_choice = valid_neighbors[0]
		var next_node = best_choice.node
		
		debug_print("RIVER:         Step %d: Node %d → %d (interior: %.2f → %.2f, Δ: %.3f)" % [
			steps, 
			current_node.node_index, 
			next_node.node_index,
			current_node.graph_interiorness_score,
			next_node.graph_interiorness_score,
			best_choice.delta
		])
		
		# Move to next node
		path.append(next_node)
		visited[next_node.node_index] = true
		current_node = next_node
	
	if current_node.is_coastal:
		debug_print("RIVER:       ✓ Reached coast at node %d after %d steps" % [current_node.node_index, steps])
	else:
		debug_print("RIVER:       ✗ Failed to reach coast (stopped at node %d after %d steps)" % [current_node.node_index, steps])
	
	return path

## Helper: Find nearest coastal node within the same region (LEGACY)
func find_nearest_coastal_node_in_region(from_node: MapNode2D, region: Region) -> MapNode2D:
	if region.coastal_nodes.size() == 0:
		debug_print("RIVER:       No coastal nodes in region %d" % region.region_id)
		return null
	
	var min_distance = INF
	var nearest = null
	
	debug_print("RIVER:       Searching %d coastal nodes in region %d" % [region.coastal_nodes.size(), region.region_id])
	
	for coastal_node in region.coastal_nodes:
		# Verify this coastal node is actually in the same region
		if coastal_node.region_id != region.region_id:
			debug_print("RIVER:         Skipping coastal node %d (different region: %d)" % [coastal_node.node_index, coastal_node.region_id])
			continue
		
		var path = astar.get_id_path(from_node.node_index, coastal_node.node_index)
		var distance = path.size()
		
		if distance > 0 and distance < min_distance:
			min_distance = distance
			nearest = coastal_node
			debug_print("RIVER:         Coastal node %d: distance=%d (current best)" % [coastal_node.node_index, distance])
	
	if nearest:
		debug_print("RIVER:       Selected coastal node %d (distance: %d)" % [nearest.node_index, min_distance])
	else:
		debug_print("RIVER:       WARNING: No reachable coastal node found in region!")
	
	return nearest

## Lake generation for landlocked rivers - Draws filled ellipse
func trigger_lake_generation_placeholder(region: Region, center_node: MapNode2D):
	debug_print("RIVER:     Region %d is LANDLOCKED - generating lake ellipse at node %d" % [region.region_id, center_node.node_index])

# ============================================================================
# LEGACY RIVER GENERATION CODE (NOT USED - Kept for reference)
# ============================================================================
# The functions below are from the old river generation system
# They are NOT used by the new intelligent region-based system
# Can be removed once new system is fully tested and polished

## Phase 2: Find target coast node for each source
func find_target_coast_for_each_source(river_sources: Array) -> Array:
	var river_paths = []
	
	for source in river_sources:
		# Calculate flow direction based on non-mountain neighbors
		var flow_direction = calculate_river_flow_direction(source.source_node, source.source_position)
		
		# Cast ray in flow direction to find where it intersects the expanded coastline
		var result = find_expanded_coast_intersection(source.source_position, flow_direction)
		
		if result == null:
			# Fallback to nearest expanded coast point
			result = find_nearest_expanded_coast_point(source.source_position)
		
		if result == null:
			continue
		
		river_paths.append({
			"river_id": source.id,
			"source_node": source.source_node,
			"source_position": source.source_position,
			"target_coast_node": result.coast_node,
			"target_position": result.position,
			"waypoints": [source.source_position, result.position],
			"merged_into": -1,
			"merge_point": Vector2.ZERO,
			"tributaries": []
		})
	
	return river_paths

## Helper: Calculate river flow direction away from mountain range
func calculate_river_flow_direction(mountain_node: MapNode2D, source_position: Vector2) -> Vector2:
	# Strategy: Flow toward interior (non-mountain) nodes
	var flow_direction = Vector2.ZERO
	var non_mountain_neighbors = []
	
	# Find all non-mountain connected nodes
	for neighbor in mountain_node.connections:
		if not neighbor.is_mountain:
			non_mountain_neighbors.append(neighbor)
	
	if non_mountain_neighbors.size() > 0:
		# Calculate average direction toward non-mountain neighbors
		for neighbor in non_mountain_neighbors:
			var neighbor_center = neighbor.position + (neighbor.size / 2.0)
			var direction = (neighbor_center - source_position).normalized()
			flow_direction += direction
		
		flow_direction = flow_direction.normalized()
	else:
		# No non-mountain neighbors - flow away from map center
		var map_center = Vector2(size.x / 2.0, size.y / 2.0)
		flow_direction = (source_position - map_center).normalized()
	
	# Add some randomness for variety
	var random_angle = randf_range(-0.3, 0.3)  # ±17 degrees
	flow_direction = flow_direction.rotated(random_angle)
	
	return flow_direction

## Helper: Find where ray intersects with expanded coastline
func find_expanded_coast_intersection(start_pos: Vector2, direction: Vector2):
	# Cast ray and find closest intersection with expanded coast line segments
	var ray_length = 2000.0
	var ray_end = start_pos + direction * ray_length
	
	var closest_intersection = null
	var min_distance = INF
	
	# Check intersection with each expanded coast line segment
	for coast_line in expanded_coast_lines:
		var seg_a = coast_line[0]
		var seg_b = coast_line[1]
		
		# Check if ray intersects this coast segment
		var intersection = line_segment_intersection(start_pos, ray_end, seg_a, seg_b)
		
		if intersection != null:
			var distance = start_pos.distance_to(intersection)
			if distance < min_distance:
				min_distance = distance
				closest_intersection = intersection
		else:
			# If no intersection, find closest point on segment to ray
			var closest_on_segment = closest_point_on_line_segment_to_ray(seg_a, seg_b, start_pos, ray_end)
			var distance = start_pos.distance_to(closest_on_segment)
			if distance < min_distance:
				min_distance = distance
				closest_intersection = closest_on_segment
	
	if closest_intersection != null:
		# Find which coastal node this point is closest to (for reference)
		var closest_node = null
		var node_min_dist = INF
		for coastal_node in coastal_nodes:
			var expanded_pos = expanded_coast_positions.get(coastal_node.node_index)
			if expanded_pos != null:
				var dist = closest_intersection.distance_to(expanded_pos)
				if dist < node_min_dist:
					node_min_dist = dist
					closest_node = coastal_node
		
		return {"position": closest_intersection, "coast_node": closest_node}
	
	return null

## Helper: Line segment intersection
func line_segment_intersection(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Variant:
	var d = (a2 - a1).cross(b2 - b1)
	if abs(d) < 0.001:
		return null  # Parallel lines
	
	var t = (b1 - a1).cross(b2 - b1) / d
	var u = (b1 - a1).cross(a2 - a1) / d
	
	if t >= 0 and t <= 1 and u >= 0 and u <= 1:
		return a1 + t * (a2 - a1)
	
	return null

## Helper: Find closest point on segment to ray
func closest_point_on_line_segment_to_ray(seg_a: Vector2, seg_b: Vector2, ray_start: Vector2, ray_end: Vector2) -> Vector2:
	# Sample points on segment and find closest to ray
	var min_dist = INF
	var best_point = seg_a
	
	for i in range(11):
		var t = float(i) / 10.0
		var point = seg_a + t * (seg_b - seg_a)
		var closest_on_ray = closest_point_on_line_segment(point, ray_start, ray_end)
		var dist = point.distance_to(closest_on_ray)
		
		if dist < min_dist:
			min_dist = dist
			best_point = point
	
	return best_point

## Helper: Find nearest expanded coast point (fallback)
func find_nearest_expanded_coast_point(position: Vector2):
	var nearest_position = null
	var nearest_node = null
	var min_distance = INF
	
	for coastal_node in coastal_nodes:
		var expanded_pos = expanded_coast_positions.get(coastal_node.node_index)
		if expanded_pos != null:
			var distance = position.distance_to(expanded_pos)
			
			if distance < min_distance:
				min_distance = distance
				nearest_position = expanded_pos
				nearest_node = coastal_node
	
	if nearest_position != null:
		return {"position": nearest_position, "coast_node": nearest_node}
	
	return null

## Phase 3: Detect river interactions
func detect_river_interactions(river_paths: Array, merge_distance_threshold: float) -> Array:
	var interactions = []
	
	for i in range(river_paths.size()):
		for j in range(i + 1, river_paths.size()):
			var river_a = river_paths[i]
			var river_b = river_paths[j]
			
			var result = find_closest_point_between_line_segments(
				river_a.waypoints[0], river_a.waypoints[1],
				river_b.waypoints[0], river_b.waypoints[1]
			)
			
			if result.distance < merge_distance_threshold:
				var distance_along_a = river_a.waypoints[0].distance_to(result.point_on_a)
				var distance_along_b = river_b.waypoints[0].distance_to(result.point_on_b)
				
				interactions.append({
					"river_a_id": river_a.river_id,
					"river_b_id": river_b.river_id,
					"merge_point": (result.point_on_a + result.point_on_b) / 2.0,
					"distance_along_a": distance_along_a,
					"distance_along_b": distance_along_b,
					"distance_between": result.distance
				})
	
	return interactions

## Helper: Find closest points between two line segments
func find_closest_point_between_line_segments(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Dictionary:
	var min_distance = INF
	var best_point_a = Vector2.ZERO
	var best_point_b = Vector2.ZERO
	
	# Sample points along line A
	for t in range(101):
		var t_norm = float(t) / 100.0
		var point_on_a = a1 + t_norm * (a2 - a1)
		var closest_on_b = closest_point_on_line_segment(point_on_a, b1, b2)
		var distance = point_on_a.distance_to(closest_on_b)
		
		if distance < min_distance:
			min_distance = distance
			best_point_a = point_on_a
			best_point_b = closest_on_b
	
	return {
		"distance": min_distance,
		"point_on_a": best_point_a,
		"point_on_b": best_point_b
	}

## Helper: Find closest point on line segment to a point
func closest_point_on_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> Vector2:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len = line_vec.length()
	
	if line_len == 0:
		return line_start
	
	var t = point_vec.dot(line_vec) / (line_len * line_len)
	t = clamp(t, 0.0, 1.0)
	
	return line_start + t * line_vec

## Phase 4: Determine merge hierarchy
func determine_merge_hierarchy(river_paths: Array, interactions: Array):
	# Sort by distance
	interactions.sort_custom(func(a, b): return a.distance_between < b.distance_between)
	
	for interaction in interactions:
		var river_a = find_river_by_id(river_paths, interaction.river_a_id)
		var river_b = find_river_by_id(river_paths, interaction.river_b_id)
		
		if river_a == null or river_b == null:
			continue
		
		# Skip if either already merged
		if river_a.merged_into != -1 or river_b.merged_into != -1:
			continue
		
		# Calculate remaining distances to coast
		var total_a = river_a.waypoints[0].distance_to(river_a.waypoints[1])
		var total_b = river_b.waypoints[0].distance_to(river_b.waypoints[1])
		var remaining_a = total_a - interaction.distance_along_a
		var remaining_b = total_b - interaction.distance_along_b
		
		# River with more remaining distance is upstream (merges into downstream)
		var upstream_river
		var downstream_river
		var merge_distance
		
		if remaining_a > remaining_b:
			upstream_river = river_a
			downstream_river = river_b
			merge_distance = interaction.distance_along_b
		else:
			upstream_river = river_b
			downstream_river = river_a
			merge_distance = interaction.distance_along_a
		
		# Record merge
		upstream_river.merged_into = downstream_river.river_id
		upstream_river.merge_point = interaction.merge_point
		downstream_river.tributaries.append({
			"tributary_river_id": upstream_river.river_id,
			"merge_point": interaction.merge_point,
			"merge_distance": merge_distance
		})

## Helper: Find river by ID
func find_river_by_id(river_paths: Array, river_id: int):
	for river in river_paths:
		if river.river_id == river_id:
			return river
	return null

## Phase 5: Build river network
func build_river_network(river_paths: Array) -> Array:
	var final_rivers = []
	
	for river in river_paths:
		# Only process rivers that reach the coast
		if river.merged_into == -1:
			var segments = build_river_segments_recursive(river, river_paths)
			final_rivers.append({
				"river_id": river.river_id,
				"segments": segments
			})
	
	return final_rivers

## Helper: Recursively build river segments
func build_river_segments_recursive(river: Dictionary, all_rivers: Array) -> Array:
	var segments = []
	var current_waypoints = [river.source_position]
	
	# Sort tributaries by merge distance
	var sorted_tributaries = river.tributaries.duplicate()
	sorted_tributaries.sort_custom(func(a, b): return a.merge_distance < b.merge_distance)
	
	# Add tributary branches
	for tributary_info in sorted_tributaries:
		current_waypoints.append(tributary_info.merge_point)
		
		var tributary_river = find_river_by_id(all_rivers, tributary_info.tributary_river_id)
		if tributary_river:
			var tributary_segments = build_river_segments_recursive(tributary_river, all_rivers)
			segments.append({
				"type": "tributary_branch",
				"segments": tributary_segments,
				"width": calculate_river_width(tributary_river, all_rivers)
			})
	
	# Add final segment to coast
	current_waypoints.append(river.target_position)
	
	segments.append({
		"type": "main_channel",
		"waypoints": current_waypoints,
		"width": calculate_river_width(river, all_rivers)
	})
	
	return segments

## Phase 6: Calculate river width based on tributaries (LEGACY - not used)
func calculate_river_width(river: Dictionary, all_rivers: Array) -> float:
	var num_tributaries = count_all_tributaries_recursive(river, all_rivers)
	var width = river_source_width + (num_tributaries)
	return clamp(width, river_end_width, river_source_width)

## Helper: Count all tributaries recursively
func count_all_tributaries_recursive(river: Dictionary, all_rivers: Array) -> int:
	var count = river.tributaries.size()
	
	for tributary_info in river.tributaries:
		var tributary_river = find_river_by_id(all_rivers, tributary_info.tributary_river_id)
		if tributary_river:
			count += count_all_tributaries_recursive(tributary_river, all_rivers)
	
	return count

## Phase 7: Add curves to rivers
func add_river_curves(final_rivers: Array) -> Array:
	var curved_rivers = []
	
	for river in final_rivers:
		var curved_segments = add_curves_to_segments(river.segments)
		curved_rivers.append({
			"river_id": river.river_id,
			"segments": curved_segments
		})
	
	return curved_rivers

## Helper: Add curves to segments recursively
func add_curves_to_segments(segments: Array) -> Array:
	var curved = []
	
	for segment in segments:
		if segment.type == "main_channel":
			var curved_waypoints = []
			var waypoints = segment.waypoints
			
			for i in range(waypoints.size() - 1):
				var start = waypoints[i]
				var end = waypoints[i + 1]
				
				# Generate bezier curve
				var midpoint = (start + end) / 2.0
				var direction = (end - start).normalized()
				var perpendicular = Vector2(-direction.y, direction.x)
				var curve_amount = randf_range(10.0, 30.0) * (1 if randf() > 0.5 else -1)
				var control_point = midpoint + perpendicular * curve_amount
				
				var curve_points = generate_quadratic_bezier(start, control_point, end, 20)
				curved_waypoints.append_array(curve_points)
			
			curved.append({
				"type": "main_channel",
				"waypoints": curved_waypoints,
				"width": segment.width
			})
		elif segment.type == "tributary_branch":
			curved.append({
				"type": "tributary_branch",
				"segments": add_curves_to_segments(segment.segments),
				"width": segment.width
			})
	
	return curved

## Helper: Generate quadratic bezier curve
func generate_quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, num_points: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	
	for i in range(num_points + 1):
		var t = float(i) / float(num_points)
		var mt = 1.0 - t
		var point = mt * mt * start + 2.0 * mt * t * control + t * t * end
		points.append(point)
	
	return points

## Render river to static map
func render_river_to_static_map(river: Dictionary):
	var river_id = river.get("id", -1)
	var is_lake = river.get("is_lake_river", false)
	
	debug_print("RIVER:   Rendering river %d (lake_river: %s)" % [river_id, is_lake])
	
	render_segments_to_static_map(river.segments)
	
	# Draw lake ellipse if this is a landlocked river
	if river.get("is_lake_river", false) and river.get("lake_position") != null:
		var lake_pos = river.lake_position * map_resolution_scale
		var lake_rad_x = river.get("lake_radius_x", lake_radius_x) * map_resolution_scale
		var lake_rad_y = river.get("lake_radius_y", lake_radius_y) * map_resolution_scale
		
		debug_print("RIVER:     Drawing lake ellipse at %s (rx: %.1f, ry: %.1f)" % [lake_pos, lake_rad_x, lake_rad_y])
		
		# Draw filled ellipse by creating concentric ellipse outlines
		var layers = 8  # Number of concentric layers to fill
		var segments_added = 0
		for layer in range(layers):
			var t = 1.0 - (float(layer) / float(layers))  # 1.0 at edge, 0.0 at center
			var rad_x = lake_rad_x * t
			var rad_y = lake_rad_y * t
			
			var circle_segments = 24
			for i in range(circle_segments):
				var angle1 = (float(i) / circle_segments) * TAU
				var angle2 = (float(i + 1) / circle_segments) * TAU
				var point_a = lake_pos + Vector2(cos(angle1) * rad_x, sin(angle1) * rad_y)
				var point_b = lake_pos + Vector2(cos(angle2) * rad_x, sin(angle2) * rad_y)
				
				static_map_renderer.add_river_segment({
					"pos_a": point_a,
					"pos_b": point_b,
					"width": max(lake_rad_x, lake_rad_y) * 0.15,  # Thick lines to fill
					"color": river_color
				})
				segments_added += 1
		
		debug_print("RIVER:     Lake rendered with %d segments (%d layers)" % [segments_added, layers])

## Helper: Render segments recursively
func render_segments_to_static_map(segments: Array):
	for segment in segments:
		if segment.type == "main_channel":
			var waypoints = segment.waypoints
			var segment_widths = segment.get("segment_widths", [])
			
			for i in range(waypoints.size() - 1):
				var point_a = waypoints[i] * map_resolution_scale
				var point_b = waypoints[i + 1] * map_resolution_scale
				
				# Use tapered width if available, otherwise use base width
				var width = segment.width * map_resolution_scale
				if segment_widths.size() > i:
					width = segment_widths[i] * map_resolution_scale
				
				# Apply horizontal width multiplier based on segment angle
				if river_horizontal_width_multiplier != 1.0:
					var direction = (point_b - point_a).normalized()
					var horizontal_factor = abs(direction.x)  # 1.0 for horizontal, 0.0 for vertical
					var width_multiplier = lerp(1.0, river_horizontal_width_multiplier, horizontal_factor)
					width *= width_multiplier
				
				static_map_renderer.add_river_segment({
					"pos_a": point_a,
					"pos_b": point_b,
					"width": width,
					"color": river_color
				})
		elif segment.type == "tributary_branch":
			render_segments_to_static_map(segment.segments)

# ============================================================================
# STEP 13: VISUALIZATION
# ============================================================================

func visualize_map():
	# Make nodes container visible
	if mapnodes:
		mapnodes.visible = true
	
	# Hide all nodes by default (they'll be revealed as party explores)
	# Exception: mountains and towns remain always visible
	for node in map_nodes:
		if node.is_mountain or node.is_town:
			node.visible = true
		else:
			node.visible = false
	
	queue_redraw()

# ============================================================================
# STATIC MAP BAKING (Performance Optimization)
# ============================================================================

## Bake static map elements to SubViewport texture
## Call this after map generation is complete
func bake_static_map():
	if not static_map_renderer or not static_map_viewport or not static_map_sprite:
		push_warning("Static map rendering nodes not found, skipping baking")
		return
	
	debug_print("Baking static map elements...")
	
	# Clear previous data
	static_map_renderer.clear_data()
	
	# Set viewport size to match map size (scaled for higher resolution)
	static_map_viewport.size = Vector2i(size * map_resolution_scale)
	
	# Pass configuration to renderer (scaled for higher resolution)
	var config = {
		"line_width": line_width * map_resolution_scale,
		"line_color": line_color,
		"use_curved_lines": use_curved_lines,
		"coastal_water_expansion": coastal_water_expansion * map_resolution_scale,
		"coastal_water_radius": coastal_water_radius * map_resolution_scale,
		"coastal_water_circles": coastal_water_circles,
		"coastal_water_color": coastal_water_color,
		"coastal_water_alpha_max": coastal_water_alpha_max,
		"biome_blob_radius": biome_blob_radius * map_resolution_scale,
		"biome_blob_circles": biome_blob_circles,
		"biome_blob_alpha_max": biome_blob_alpha_max
	}
	static_map_renderer.set_config(config)
	
	# Pass rivers data FIRST (bottom layer under everything)
	if enable_rivers and rivers.size() > 0:
		for river in rivers:
			render_river_to_static_map(river)
	
	# Pass feature data (trees, etc.) so they render above rivers
	if enable_map_features and map_features.size() > 0:
		for feature in map_features:
			match feature.type:
				"tree":
					# Scale tree data
					var tree_data = feature.data.duplicate()
					tree_data["position"] = tree_data["position"] * map_resolution_scale
					tree_data["foliage_radius"] = tree_data["foliage_radius"] * map_resolution_scale
					tree_data["trunk_width"] = tree_data["trunk_width"] * map_resolution_scale
					tree_data["trunk_length"] = tree_data["trunk_length"] * map_resolution_scale
					tree_data["outline_width"] = tree_data["outline_width"] * map_resolution_scale
					static_map_renderer.add_tree(tree_data)
				# Future: add other feature types here
	
	# Pass connection lines data (ONLY ROADS - regular paths drawn dynamically)
	var processed_edges = {}
	for node in map_nodes:
		for neighbor in node.connections:
			# Avoid processing same edge twice
			var key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
			if processed_edges.has(key):
				continue
			processed_edges[key] = true
			
			# Check if this edge is a road
			var is_road_edge = is_road(node, neighbor)
			
			# ONLY bake roads into static layer - regular paths will be drawn dynamically
			if not is_road_edge:
				continue
			
			# Get positions (center of nodes)
			var pos_a = node.position + (node.size / 2.0)
			var pos_b = neighbor.position + (neighbor.size / 2.0)
			
			# Use road styling
			var base_width = line_width * road_width_multiplier
			var base_color = road_color
			
			# Adjust for orientation
			var adjusted_width = get_orientation_adjusted_width(base_width, pos_a, pos_b)
			var adjusted_color = get_orientation_adjusted_color(base_color, pos_a, pos_b)
			
			# Build line data (scale positions and widths)
			var line_data = {
				"pos_a": pos_a * map_resolution_scale,
				"pos_b": pos_b * map_resolution_scale,
				"color": adjusted_color,
				"width": adjusted_width * map_resolution_scale
			}
			
			# Add curve data if using curved lines (scale control points)
			if use_curved_lines:
				var curve_data = _get_curve_data_for_line(pos_a, pos_b, node, neighbor)
				var scaled_curve_data = {}
				
				# Scale control points
				if curve_data.has("control_point"):
					scaled_curve_data["control_point"] = curve_data["control_point"] * map_resolution_scale
				if curve_data.has("control1"):
					scaled_curve_data["control1"] = curve_data["control1"] * map_resolution_scale
				if curve_data.has("control2"):
					scaled_curve_data["control2"] = curve_data["control2"] * map_resolution_scale
				if curve_data.has("is_s_curve"):
					scaled_curve_data["is_s_curve"] = curve_data["is_s_curve"]
				
				line_data["curve_data"] = scaled_curve_data
			
			static_map_renderer.add_connection_line(line_data)
			
			# Create highlight/shadow version (offset and lighter, scaled)
			var offset = Vector2(2, 2) * map_resolution_scale  # Scaled offset
			var highlight_color = adjusted_color.lightened(0.15)  # Slightly lighter
			
			var highlight_data = {
				"pos_a": pos_a * map_resolution_scale + offset,
				"pos_b": pos_b * map_resolution_scale + offset,
				"color": highlight_color,
				"width": adjusted_width * map_resolution_scale
			}
			
			# Add same curve data if using curved lines (already scaled, just offset)
			if use_curved_lines and line_data.has("curve_data"):
				# Properly duplicate curve data and offset control points
				var original_curve = line_data["curve_data"]
				var highlight_curve = original_curve.duplicate(true)  # Deep copy
				
				# Offset control points based on curve type (they're already scaled)
				if highlight_curve.has("control1"):
					highlight_curve["control1"] = highlight_curve["control1"] + offset
				if highlight_curve.has("control2"):
					highlight_curve["control2"] = highlight_curve["control2"] + offset
				if highlight_curve.has("control_point"):
					highlight_curve["control_point"] = highlight_curve["control_point"] + offset
				
				highlight_data["curve_data"] = highlight_curve
			
			static_map_renderer.add_connection_line_highlight(highlight_data)
	
	# Pass coastal water blobs data (scale positions)
	if enable_coastal_water_blobs and coastal_nodes.size() > 0 and coastal_water_circles > 0:
		for node in coastal_nodes:
			var node_center = node.position + (node.size / 2.0)
			var blob_data = {
				"node_center": node_center * map_resolution_scale,
				"away_direction": node.away_direction
			}
			static_map_renderer.add_coastal_water_blob(blob_data)
	
	# Pass landmass polygon data (scale polygon points)
	if enable_landmass_shading and expanded_coast_lines.size() > 0:
		var polygon_points = build_coast_polygon()
		if polygon_points.size() >= 3:
			# Scale all polygon points
			var scaled_polygon = PackedVector2Array()
			for point in polygon_points:
				scaled_polygon.append(point * map_resolution_scale)
			static_map_renderer.set_landmass_polygon(scaled_polygon, landmass_base_color)
	
	# Pass biome blobs data (scale positions)
	if enable_biome_blobs and map_nodes.size() > 0 and biome_blob_circles > 0:
		for node in map_nodes:
			if node.is_mountain or node.biome == null:
				continue
			var center = node.position + (node.size / 2.0)
			var blob_data = {
				"center": center * map_resolution_scale,
				"biome_color": node.biome.color
			}
			static_map_renderer.add_biome_blob(blob_data)
	
	# Pass coast ripple lines data
	if enable_coast_ripples and ripple_count > 0 and coastal_nodes.size() > 0 and coastal_connections.size() > 0:
		# For each ripple layer (outermost first)
		for ripple_index in range(ripple_count - 1, -1, -1):
			# Calculate additional distance for this ripple (beyond the coast expansion)
			var additional_ripple_distance = 0.0
			for i in range(ripple_index + 1):
				if i == 0:
					additional_ripple_distance += ripple_base_spacing
				else:
					additional_ripple_distance += ripple_base_spacing * pow(ripple_spacing_growth, i)
			
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
			# Each node uses its own variable expansion distance as the base
			var ripple_positions: Dictionary = {}
			for node in coastal_nodes:
				var node_center = node.position + (node.size / 2.0)
				var away_vector = Vector2(cos(node.away_direction), sin(node.away_direction))
				# Get this node's variable expansion distance
				var expansion_factor = coast_expansion_factors.get(node.node_index, 0.5)
				var expansion_distance = lerp(coast_expansion_min, coast_expansion_max, expansion_factor)
				# Add the additional ripple distance on top
				var cumulative_distance = expansion_distance + additional_ripple_distance
				var ripple_pos = node_center + away_vector * cumulative_distance
				ripple_positions[node.node_index] = ripple_pos
			
			# Add ripple lines for each coastal connection
			for connection in coastal_connections:
				var node_a = connection[0]
				var node_b = connection[1]
				
				var pos_a = ripple_positions.get(node_a.node_index)
				var pos_b = ripple_positions.get(node_b.node_index)
				
				if pos_a != null and pos_b != null:
					var adjusted_width = get_orientation_adjusted_width(ripple_width, pos_a, pos_b)
					var ripple_data = {
						"pos_a": pos_a * map_resolution_scale,
						"pos_b": pos_b * map_resolution_scale,
						"color": ripple_color,
						"width": adjusted_width * map_resolution_scale
					}
					static_map_renderer.add_coast_ripple_line(ripple_data)
	
	# Pass expanded coast lines data (scale positions and widths)
	if expanded_coast_lines.size() > 0:
		for coast_line in expanded_coast_lines:
			var pos_a = coast_line[0]
			var pos_b = coast_line[1]
			
			# Adjust line width based on orientation
			var adjusted_coast_width = get_orientation_adjusted_width(coast_line_width, pos_a, pos_b)
			
			var coast_line_data = {
				"pos_a": pos_a * map_resolution_scale,
				"pos_b": pos_b * map_resolution_scale,
				"color": coast_line_color,
				"width": adjusted_coast_width * map_resolution_scale
			}
			static_map_renderer.add_expanded_coast_line(coast_line_data)
	
	# Pass town marker data (scale positions and radii)
	if town_nodes.size() > 0:
		for town in town_nodes:
			var town_center = town.position + (town.size / 2.0)
			var marker_data = {
				"position": town_center * map_resolution_scale,
				"radius": 8.0 * map_resolution_scale,
				"color": Color(1.0, 0.9, 0.3, 0.8),
				"center_color": Color(0.8, 0.6, 0.1, 1.0)
			}
			static_map_renderer.add_town_marker(marker_data)
	
	# Trigger render
	static_map_renderer.queue_redraw()
	
	# Wait for render to complete
	await RenderingServer.frame_post_draw
	
	# Capture texture and display (scale sprite down to original size)
	static_map_sprite.texture = static_map_viewport.get_texture()
	static_map_sprite.scale = Vector2.ONE / map_resolution_scale  # Scale down to compensate for high-res texture
	static_map_sprite.visible = true
	
	var water_blob_count = coastal_nodes.size() if (enable_coastal_water_blobs and coastal_water_circles > 0) else 0
	var landmass_points = static_map_renderer.landmass_polygon.size()
	var biome_blob_count = static_map_renderer.biome_blobs_data.size()
	var ripple_line_count = static_map_renderer.coast_ripple_lines_data.size()
	var coast_line_count = static_map_renderer.expanded_coast_lines_data.size()
	var tree_count = static_map_renderer.trees_data.size()
	var river_count = rivers.size()
	debug_print("Static map baked successfully: %d rivers, %d connection lines, %d coastal water blobs, landmass (%d pts), %d biome blobs, %d trees, %d coast ripples, %d coast lines" % [river_count, processed_edges.size(), water_blob_count, landmass_points, biome_blob_count, tree_count, ripple_line_count, coast_line_count])

# ============================================================================
# MAP DECORATIONS (Dragons, Octopi, etc.)
# ============================================================================

func position_map_decorations():
	if coastal_nodes.size() == 0:
		debug_print("  No coastal nodes found, skipping decoration placement")
		return
	
	# Get map bounds (the Control's size)
	var map_bounds = size
	
	# Find coastal nodes in all 8 directions
	var southwest_node: MapNode2D = null
	var northeast_node: MapNode2D = null
	var east_node: MapNode2D = null
	var west_node: MapNode2D = null
	var northwest_node: MapNode2D = null
	var southeast_node: MapNode2D = null
	
	var min_sw_score: float = INF
	var max_ne_score: float = -INF
	var max_east_x: float = -INF
	var min_west_x: float = INF
	var min_nw_score: float = INF
	var max_se_score: float = -INF
	
	for node in coastal_nodes:
		var node_center = node.position + (node.size / 2.0)
		
		# Southwest: x - y (minimize for left + down)
		var sw_score = node_center.x - node_center.y
		if sw_score < min_sw_score:
			min_sw_score = sw_score
			southwest_node = node
		
		# Northeast: x - y (maximize for right + up)
		var ne_score = node_center.x - node_center.y
		if ne_score > max_ne_score:
			max_ne_score = ne_score
			northeast_node = node
		
		# East: maximize x
		if node_center.x > max_east_x:
			max_east_x = node_center.x
			east_node = node
		
		# West: minimize x
		if node_center.x < min_west_x:
			min_west_x = node_center.x
			west_node = node
		
		# Northwest: x + y (minimize for left + up)
		var nw_score = node_center.x + node_center.y
		if nw_score < min_nw_score:
			min_nw_score = nw_score
			northwest_node = node
		
		# Southeast: x + y (maximize for right + down)
		var se_score = node_center.x + node_center.y
		if se_score > max_se_score:
			max_se_score = se_score
			southeast_node = node
	
	# Helper function to position a sprite
	var position_sprite = func(sprite: Sprite2D, node: MapNode2D, direction: Vector2, direction_name: String, clamp_to_bounds: bool = true):
		if not sprite or not node:
			return
		
		var node_center = node.position + (node.size / 2.0)
		var decoration_pos = node_center + direction.normalized() * decoration_distance_from_coast
		
		# Optionally clamp position to stay within map bounds
		if clamp_to_bounds:
			var sprite_half_size = sprite.texture.get_size() * sprite.scale / 2.0 if sprite.texture else Vector2(32, 32)
			var min_bounds = sprite_half_size + Vector2(decoration_edge_margin, decoration_edge_margin)
			var max_bounds = map_bounds - sprite_half_size - Vector2(decoration_edge_margin, decoration_edge_margin)
			decoration_pos.x = clamp(decoration_pos.x, min_bounds.x, max_bounds.x)
			decoration_pos.y = clamp(decoration_pos.y, min_bounds.y, max_bounds.y)
		
		sprite.position = decoration_pos
		sprite.visible = true
		debug_print("  Positioned %s sprite at %s %s from node %d" % [sprite.name, decoration_pos, direction_name, node.node_index])
	
	# Position all sprites (waves can go off-screen, dagron/octopi stay on-screen)
	position_sprite.call(dagron_sprite, southwest_node, Vector2(-1.0, 1.0), "SOUTHWEST", true)
	position_sprite.call(octopi_sprite, northeast_node, Vector2(1.0, -1.0), "NORTHEAST", true)
	position_sprite.call(waves_east_sprite, east_node, Vector2(1.0, 0.0), "EAST", false)
	position_sprite.call(waves_west_sprite, west_node, Vector2(-1.0, 0.0), "WEST", false)
	position_sprite.call(waves_northwest_sprite, northwest_node, Vector2(-1.0, -1.0), "NORTHWEST", false)
	position_sprite.call(waves_southeast_sprite, southeast_node, Vector2(1.0, 1.0), "SOUTHEAST", false)

## Helper to extract curve data for a connection line (matches draw_curved_line logic)
func _get_curve_data_for_line(pos_a: Vector2, pos_b: Vector2, node_a: MapNode2D, node_b: MapNode2D) -> Dictionary:
	var direction = (pos_b - pos_a).normalized()
	var distance = pos_a.distance_to(pos_b)
	
	# Use EXACT same logic as draw_curved_line and get_path_points
	var direction_hash = hash(Vector2i(int(pos_a.x), int(pos_a.y)) + Vector2i(int(pos_b.x), int(pos_b.y)))
	var curve_dir = 1.0 if direction_hash % 2 == 0 else -1.0
	
	var node_hash = hash(str(node_a.node_index) + "_" + str(node_b.node_index))
	var use_s_curve = distance > s_curve_threshold and (float(node_hash % 100) / 100.0) < s_curve_probability
	
	var perpendicular = Vector2(-direction.y, direction.x) * curve_dir
	var min_strength = curve_strength * 0.2
	var max_strength = curve_strength * 0.5
	var strength_hash = hash(str(node_b.node_index) + "_" + str(node_a.node_index))
	var random_strength = min_strength + (max_strength - min_strength) * (float(strength_hash % 100) / 100.0)
	var base_offset = distance * random_strength
	
	if use_s_curve:
		# S-curve with two control points
		var control1 = pos_a + direction * (distance * 0.33) + perpendicular * base_offset
		var control2 = pos_a + direction * (distance * 0.67) - perpendicular * base_offset
		return {
			"is_s_curve": true,
			"control1": control1,
			"control2": control2
		}
	else:
		# Single curve with one control point
		var control_offset = perpendicular * base_offset
		var control_point = (pos_a + pos_b) / 2.0 + control_offset
		return {
			"is_s_curve": false,
			"control_point": control_point
		}

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
		
		# Cubic Bezier curve (4 points: start, control1, control2, end) - fixed segment count for consistent performance
		var segments = 24
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
		
		# Quadratic Bezier curve (3 points: start, control, end) - fixed segment count for consistent performance
		var segments = 16
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
	
	# Draw coastal water blobs FIRST (skip if using static rendering - they're baked into texture)
	if enable_coastal_water_blobs and not use_static_rendering:
		draw_coastal_water_blobs()
	
	# Draw landmass fill (skip if using static rendering - it's baked into texture)
	if enable_landmass_shading and expanded_coast_lines.size() > 0 and not use_static_rendering:
		draw_landmass_fill()
	
	# Draw biome blobs (skip if using static rendering - they're baked into texture)
	if enable_biome_blobs and not use_static_rendering:
		draw_biome_blobs()
	
	# Draw connection lines dynamically (ONLY visible regular paths, NOT roads)
	var edges_drawn = 0
	var processed_edges = {}
	
	for node in map_nodes:
		for neighbor in node.connections:
			# Avoid drawing same edge twice
			var key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
			if processed_edges.has(key):
				continue
			processed_edges[key] = true
			
			# Check if this edge is a road
			var is_road_edge = is_road(node, neighbor)
			
			# Skip roads - they're baked into static layer
			if is_road_edge:
				continue
			
			# Skip if static rendering is enabled (all roads are baked, regular paths are dynamic)
			if use_static_rendering:
				# Check if this path is visible
				if not is_path_visible(node, neighbor):
					continue  # Not visible, don't draw
			
			# Control nodes position from top-left, so add half size for center
			var pos_a = node.position + (node.size / 2.0)
			var pos_b = neighbor.position + (neighbor.size / 2.0)
			
			# Use regular path styling
			var base_width = line_width
			var base_color = line_color
			
			# Adjust line width and color based on orientation
			var adjusted_width = get_orientation_adjusted_width(base_width, pos_a, pos_b)
			var adjusted_color = get_orientation_adjusted_color(base_color, pos_a, pos_b)
			
			if use_curved_lines:
				# Draw smooth Bezier curve with variation
				draw_curved_line(pos_a, pos_b, adjusted_color, adjusted_width, node, neighbor)
			else:
				# Draw straight line
				draw_line(pos_a, pos_b, adjusted_color, adjusted_width)
	
	# Draw coastal ripples (skip if using static rendering - they're baked into texture)
	if enable_coast_ripples and ripple_count > 0 and not use_static_rendering:
		draw_coast_ripples()
	
	# Draw player trail (completed paths)
	draw_player_trail()
	
	# Draw current travel path (in progress)
	if map_state == MapState.PARTY_MOVING and current_travel_path.size() > 1:
		draw_dotted_path(current_travel_path, trail_color, trail_line_width)
	
	# Draw hover preview path
	if hover_preview_path.size() > 1:
		draw_preview_path(hover_preview_path)
	
	# Draw expanded coast lines (skip if using static rendering - they're baked into texture)
	if not use_static_rendering:
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
	
	# Draw town markers (visual indicator for towns)
	if not use_static_rendering:
		for town in town_nodes:
			var town_center = town.position + (town.size / 2.0)
			var marker_radius = 8.0
			# Draw a bright circle to mark towns
			draw_circle(town_center, marker_radius, Color(1.0, 0.9, 0.3, 0.8))  # Golden yellow
			draw_circle(town_center, marker_radius * 0.6, Color(0.8, 0.6, 0.1, 1.0))  # Darker center
	

# ============================================================================
# COASTAL WATER BLOBS (under landmass)
# ============================================================================

func draw_coastal_water_blobs():
	if coastal_nodes.size() == 0 or coastal_water_circles < 1:
		return
	for node in coastal_nodes:
		var node_center = node.position + (node.size / 2.0)
		var away = Vector2(cos(node.away_direction), sin(node.away_direction))
		var center = node_center + away * coastal_water_expansion
		var base = coastal_water_color
		# Concentric circles: gradient from center (strong) to edge (fade)
		# Alpha = color.a * alpha_max * gradient (so exported color is fully respected)
		for i in range(coastal_water_circles):
			var t = float(i) / float(coastal_water_circles)
			var r = coastal_water_radius * (1.0 - t)
			var a = base.a * coastal_water_alpha_max * (0.1 + 0.9 * t)
			var col = Color(base.r, base.g, base.b, a)
			draw_circle(center, r, col)

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
		# Calculate additional distance for this ripple (beyond the coast expansion)
		var additional_ripple_distance = 0.0
		for i in range(ripple_index + 1):
			if i == 0:
				additional_ripple_distance += ripple_base_spacing
			else:
				additional_ripple_distance += ripple_base_spacing * pow(ripple_spacing_growth, i)
		
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
		# Each node uses its own variable expansion distance as the base
		var ripple_positions: Dictionary = {}
		for node in coastal_nodes:
			var node_center = node.position + (node.size / 2.0)
			var away_vector = Vector2(cos(node.away_direction), sin(node.away_direction))
			# Get this node's variable expansion distance
			var expansion_factor = coast_expansion_factors.get(node.node_index, 0.5)
			var expansion_distance = lerp(coast_expansion_min, coast_expansion_max, expansion_factor)
			# Add the additional ripple distance on top
			var cumulative_distance = expansion_distance + additional_ripple_distance
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
		debug_print("DEBUG: Landmass polygon has < 3 points: %d" % polygon_points.size())
		return  # Need at least 3 points for a polygon
	
	# Draw filled polygon with solid color (no gradient)
	debug_print("DEBUG: Drawing landmass with %d points" % polygon_points.size())
	draw_colored_polygon(polygon_points, landmass_base_color)

func build_coast_polygon() -> PackedVector2Array:
	# Build a closed polygon by traversing coastal nodes in connection order
	# Use the CACHED expanded positions to ensure perfect alignment with coast lines
	if coastal_nodes.size() == 0 or expanded_coast_lines.size() == 0:
		return PackedVector2Array()
	
	# Use the cached expanded_coast_positions that were calculated in generate_expanded_coast()
	# This guarantees we use the EXACT same positions as the coast lines
	
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
		var current_pos = expanded_coast_positions.get(current_node_index)
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
				var candidate_pos = expanded_coast_positions.get(candidate_index)
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

# ============================================================================
# BIOME BLOBS (Stage 1: soft circles per node, no masking)
# ============================================================================

func draw_biome_blobs():
	if map_nodes.size() == 0 or biome_blob_circles < 1:
		return
	for node in map_nodes:
		if node.is_mountain or node.biome == null:
			continue
		var center = node.position + (node.size / 2.0)
		var base = node.biome.color
		# Concentric filled circles, outer → inner. Faint at edge, stronger at center.
		for i in range(biome_blob_circles):
			var t = float(i) / float(biome_blob_circles)
			var r = biome_blob_radius * (1.0 - t)
			var a = biome_blob_alpha_max * (0.1 + 0.9 * t)
			var col = Color(base.r, base.g, base.b, a)
			draw_circle(center, r, col)

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
	
	debug_print("Party spawned at node %d" % spawn_node.node_index)

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
	
	# Update node visibility (show current + connected nodes only)
	update_node_visibility()
	
	# Hide rest button initially - events will determine if rest is safe (RestButton now in MapUI)
	if has_node("%RestButton"):
		%RestButton.visible = false
	
	# Emit signal so systems can react to party movement
	party_moved_to_node.emit(node)

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

## Update node visibility based on party position
## Only shows: current node, connected nodes (non-secret), towns, and mountains
func update_node_visibility():
	if not current_party_node:
		return
	
	# Hide all non-mountain, non-town nodes first
	for node in map_nodes:
		if node.is_mountain or node.is_town:
			# Mountains and towns always visible
			node.visible = true
		else:
			# Everything else hidden by default
			node.visible = false
	
	# Show current node
	current_party_node.visible = true
	
	# Show all connected nodes (but ONLY via non-secret paths!)
	for neighbor in current_party_node.connections:
		# Check if the path to this neighbor is secret and hidden
		if is_edge_secret_and_hidden(current_party_node, neighbor):
			# Don't reveal this neighbor - the path is secret!
			continue
		
		neighbor.visible = true
	
	# Request redraw to update path visibility
	queue_redraw()

## Check if a path between two nodes should be visible
## A path is visible if at least one end is the current party node (prevents showing paths between adjacent visible nodes)
func is_path_visible(node_a: MapNode2D, node_b: MapNode2D) -> bool:
	if not current_party_node:
		return false
	
	# Check if this path is a secret that hasn't been revealed
	if is_edge_secret_and_hidden(node_a, node_b):
		return false  # Secret paths are never visible until revealed
	
	# Path is visible only if at least one endpoint is the current party node
	# This prevents showing connections between other visible nodes (like B-C when party is at A)
	var is_connected_to_party = (node_a == current_party_node or node_b == current_party_node)
	
	# Both nodes must still be in visibility range
	var node_a_in_range = is_node_within_visibility_range(node_a)
	var node_b_in_range = is_node_within_visibility_range(node_b)
	
	return is_connected_to_party and node_a_in_range and node_b_in_range

## Check if a node is within visibility range of the party
func is_node_within_visibility_range(node: MapNode2D) -> bool:
	if not current_party_node:
		return false
	
	# Current node is always in range
	if node == current_party_node:
		return true
	
	# Use AStar to calculate distance
	if not astar:
		# Fallback: only show immediately connected nodes
		return current_party_node.is_connected_to(node)
	
	var path = astar.get_id_path(current_party_node.node_index, node.node_index)
	var distance = path.size() - 1 if path.size() > 0 else 999
	
	# Node is in range if distance <= visibility range
	return distance <= (path_visibility_range + 1)  # +1 because range 0 means "1 step away" (adjacent)

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
		
		var segments = 24  # Fixed for consistent performance
		
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
		
		var segments = 16  # Fixed for consistent performance
		
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
	
	# Clear rested node tracking when leaving current node
	clear_rested_node()
	
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
	
	debug_print("Party started traveling to node %d" % target_node.node_index)

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
		
		debug_print("Party moved to node %d" % travel_target_node.node_index)
		
		# Emit travel completed signal (only when actual travel happened)
		travel_completed.emit(travel_target_node)
	
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

## Rest button logic moved to MapUI under UIController - Main handles rest_requested and visibility

## Mark that the party has successfully rested at the current node
func mark_node_as_rested():
	if current_party_node:
		rested_at_node_index = current_party_node.node_index
		# Main updates rest button visibility in _on_rest_complete

## Clear rested node tracking (called when party leaves a node)
func clear_rested_node():
	rested_at_node_index = -1

## Handle node click for navigation during gameplay
func handle_node_navigation(clicked_node: MapNode2D):
	if map_state == MapState.PARTY_MOVING:
		debug_print("Party is already traveling, ignoring click")
		return
	
	if not current_party_node:
		debug_print("Party not spawned yet, ignoring click")
		return
	
	# Check if this is a valid move
	if can_party_move_to(clicked_node):
		navigate_party_to_node(clicked_node)
	else:
		debug_print("Cannot move to node %d (not connected or invalid)" % clicked_node.node_index)

func _handle_generation_error(message: String):
	push_error(message)
	if auto_regenerate_on_error:
		debug_print("  → Auto-regeneration enabled, will regenerate map after current generation completes")
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
	
	var location: Dictionary = {}
	
	# Get biome name
	if node.biome:
		location["biome"] = node.biome.display_name
	else:
		location["biome"] = "Unknown"
	
	# Get steps away from player
	if current_party_node and astar:
		var path = astar.get_id_path(current_party_node.node_index, node.node_index)
		location["steps"] = path.size() - 1 if path.size() > 0 else 0
	else:
		location["steps"] = 0
	
	# Check if visited
	location["visited"] = node.node_state != MapNode2D.NodeState.UNEXPLORED
	
	# Check if this is a town
	location["is_town"] = node.is_town
	
	%LocationDetailDisplay.location_hovered(location)
	
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
	%LocationDetailDisplay.hide()
	
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
	debug_print("\n=== DEBUG: Node %d Away Direction Analysis ===" % node.node_index)
	debug_print("Node %d: is_coastal=%s, connections=%d" % [node.node_index, node.is_coastal, node.connections.size()])
	
	var away_deg = rad_to_deg(node.away_direction) if node.away_direction != 0.0 else 0.0
	var away_str = "%.1f° (%.4f rad)" % [away_deg, node.away_direction] if node.away_direction != 0.0 else "NOT SET (0.0)"
	debug_print("  Node %d away_direction: %s" % [node.node_index, away_str])
	
	if node.is_coastal:
		var node_center = node.position + (node.size / 2.0)
		var away_vec = Vector2(cos(node.away_direction), sin(node.away_direction))
		var expansion_factor = coast_expansion_factors.get(node.node_index, 0.5)
		var expansion_distance = lerp(coast_expansion_min, coast_expansion_max, expansion_factor)
		var expanded_pos = node_center + away_vec * expansion_distance
		debug_print("  Node %d center: (%.1f, %.1f)" % [node.node_index, node_center.x, node_center.y])
		debug_print("  Node %d away_vector: (%.3f, %.3f)" % [node.node_index, away_vec.x, away_vec.y])
		debug_print("  Node %d expansion_factor: %.3f, expansion_distance: %.1f" % [node.node_index, expansion_factor, expansion_distance])
		debug_print("  Node %d expanded_pos: (%.1f, %.1f)" % [node.node_index, expanded_pos.x, expanded_pos.y])
	
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
			debug_print("  PASS 1 LOGIC ANALYSIS (3+ coastal neighbors):")
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
			
			debug_print("    Total coastal neighbors: %d" % coastal_neighbors.size())
			debug_print("    Coastal neighbors WITH coastal edges: %d" % coastal_neighbors_with_coastal_edges.size())
			
			if coastal_neighbors_with_coastal_edges.size() == 2:
				var used_1 = coastal_neighbors_with_coastal_edges[0]
				var used_2 = coastal_neighbors_with_coastal_edges[1]
				debug_print("    ✓ USED FOR ARC: Neighbors %d and %d" % [used_1.node_index, used_2.node_index])
				
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
				debug_print("    Arc 1: %.1f° to %.1f° (span=%.1f°)" % [rad_to_deg(arc_1_start), rad_to_deg(arc_1_end), rad_to_deg(arc_1_span)])
				debug_print("    Arc 2: %.1f° to %.1f° (span=%.1f°)" % [rad_to_deg(arc_1_end), rad_to_deg(arc_1_start + TAU), rad_to_deg(arc_2_span)])
			else:
				debug_print("    ✗ ERROR: Expected 2 coastal neighbors with coastal edges, got %d" % coastal_neighbors_with_coastal_edges.size())
				if coastal_neighbors_with_coastal_edges.size() > 0:
					debug_print("    Would have used: %s" % str(coastal_neighbors_with_coastal_edges.map(func(n): return n.node_index)))
	
	debug_print("  All Neighbors:")
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
		debug_print("    Neighbor %d: is_coastal=%s, %s, away_direction=%s, angle_to_neighbor=%.1f°" % [neighbor.node_index, neighbor.is_coastal, edge_status, neighbor_away_str, angle_to_neighbor_deg])
		
		if neighbor.is_coastal and neighbor.away_direction != 0.0:
			var neighbor_away_vec = Vector2(cos(neighbor.away_direction), sin(neighbor.away_direction))
			var neighbor_expansion_factor = coast_expansion_factors.get(neighbor.node_index, 0.5)
			var neighbor_expansion_distance = lerp(coast_expansion_min, coast_expansion_max, neighbor_expansion_factor)
			var neighbor_expanded_pos = neighbor_center + neighbor_away_vec * neighbor_expansion_distance
			debug_print("      Neighbor %d center: (%.1f, %.1f)" % [neighbor.node_index, neighbor_center.x, neighbor_center.y])
			debug_print("      Neighbor %d away_vector: (%.3f, %.3f)" % [neighbor.node_index, neighbor_away_vec.x, neighbor_away_vec.y])
			debug_print("      Neighbor %d expansion_factor: %.3f, distance: %.1f" % [neighbor.node_index, neighbor_expansion_factor, neighbor_expansion_distance])
			debug_print("      Neighbor %d expanded_pos: (%.1f, %.1f)" % [neighbor.node_index, neighbor_expanded_pos.x, neighbor_expanded_pos.y])
	
	debug_print("=== End Away Direction Debug ===\n")

func debug_node_edges(node: MapNode2D):
	debug_print("\n=== DEBUG: Node %d Edge Analysis ===" % node.node_index)
	debug_print("Node %d is currently marked as coastal: %s" % [node.node_index, node.is_coastal])
	debug_print("Node %d has %d connections" % [node.node_index, node.connections.size()])
	debug_print("")
	
	# Analyze each edge connected to this node
	for neighbor in node.connections:
		var edge_key = str(min(node.node_index, neighbor.node_index)) + "_" + str(max(node.node_index, neighbor.node_index))
		
		# Count triangles containing this edge (DETAILED)
		var triangle_count = 0
		var triangle_nodes: Array = []
		var all_candidates: Array = []  # All nodes checked
		
		debug_print("  Edge %d-%d: Checking for triangles..." % [node.node_index, neighbor.node_index])
		for node_c in node.connections:
			if node_c == neighbor:
				continue
			all_candidates.append(node_c.node_index)
			# Check if node_c is also connected to neighbor (forms triangle)
			var is_connected_to_neighbor = node_c in neighbor.connections
			debug_print("    Checking node %d: connected to neighbor? %s" % [node_c.node_index, is_connected_to_neighbor])
			if is_connected_to_neighbor:
				triangle_count += 1
				triangle_nodes.append(node_c.node_index)
				debug_print("      -> Triangle found: %d-%d-%d" % [node.node_index, neighbor.node_index, node_c.node_index])
				if triangle_count >= 2:
					debug_print("      -> Reached 2 triangles, stopping")
					break  # Interior edges have exactly 2 triangles
		
		debug_print("    All candidates checked: %s" % str(all_candidates))
		
		# Determine if this is a boundary edge
		var is_boundary_edge = triangle_count < 2
		var edge_type = "BOUNDARY" if is_boundary_edge else "INTERIOR"
		
		debug_print("  Edge %d-%d:" % [node.node_index, neighbor.node_index])
		debug_print("    Neighbor %d is coastal: %s" % [neighbor.node_index, neighbor.is_coastal])
		debug_print("    Triangle count: %d" % triangle_count)
		if triangle_count > 0:
			debug_print("    Triangles: %s" % str(triangle_nodes))
		debug_print("    Edge type: %s (triangle_count < 2 = %s)" % [edge_type, is_boundary_edge])
		
		# Check if this edge is in coastal_connections
		var in_coastal_connections = false
		for conn in coastal_connections:
			if (conn[0] == node and conn[1] == neighbor) or (conn[0] == neighbor and conn[1] == node):
				in_coastal_connections = true
				break
		debug_print("    In coastal_connections: %s" % in_coastal_connections)
		debug_print("")
	
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
	
	debug_print("SUMMARY:")
	debug_print("  Boundary edges: %d" % boundary_edge_count)
	debug_print("  Coastal neighbors: %d" % coastal_neighbor_count)
	debug_print("  Non-coastal neighbors: %d" % non_coastal_neighbor_count)
	debug_print("  Should be coastal: %s (has boundary edges: %d > 0)" % [boundary_edge_count > 0, boundary_edge_count])
	debug_print("=== End Debug ===\n")
