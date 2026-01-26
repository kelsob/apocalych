extends Control
class_name MapNode2D

## Simplified 2D MapNode for graph generation

# Node types
enum NodeType {
	TOWN,
	EVENT
}

# Node states
enum NodeState {
	UNEXPLORED,
	CURRENT,
	CLEARED,
	FLED
}

# Signals
signal node_clicked(node: MapNode2D)
signal node_hovered(node: MapNode2D)
signal node_hover_ended(node: MapNode2D)

# Core properties
var node_index: int = -1
var node_type: NodeType = NodeType.EVENT
var node_state: NodeState = NodeState.UNEXPLORED
var connections: Array[MapNode2D] = []

# Event data
var event_data = null

# Rest state
var can_rest_here: bool = false  # Whether party can rest at this node

# Terrain properties
var is_coastal: bool = false
var is_lake_coast: bool = false
var is_lake: bool = false
var is_pivot_node: bool = false
var coastal_loop_id: int = -1
var boundary_edge_count: int = 0
var is_mountain: bool = false
var biome: Biome = null

# Distance metrics
var distance_to_coast: float = 0.0
var distance_to_center: float = 0.0
var interiorness_score: float = 0.0
var graph_interiorness_score: float = 0.0
var graph_distance_to_coast: int = 0
var graph_distance_to_center: int = 0

# Region assignment
var region_id: int = -1
var region_seed: MapNode2D = null
var is_poi: bool = false
var poi_type: String = ""

# Coast expansion
var away_direction: float = 0.0  # Angle in radians for coast expansion direction

# Visuals
var node_color: Color = Color.WHITE

@onready var sprite_base = $BaseSprite
@onready var sprite_mountain = $MountainSprite


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Center sprites in Control
	for child in get_children():
		if child is Sprite2D and child.position == Vector2.ZERO:
			child.position = size / 2.0

func on_clicked():
	node_clicked.emit(self)

func set_node_type(type: NodeType):
	node_type = type

func set_state(new_state: NodeState):
	node_state = new_state

func get_description() -> String:
	var type_name = NodeType.keys()[node_type]
	var state_name = NodeState.keys()[node_state]
	return "Node %d: %s (%s)" % [node_index, type_name, state_name]

func is_connected_to(other_node: MapNode2D) -> bool:
	return other_node in connections

func get_connection_count() -> int:
	return connections.size()

func is_dead_end() -> bool:
	return connections.size() == 1

func set_debug_color(color: Color):
	is_poi = true
	node_color = color
	modulate = color

func set_region_color(color: Color):
	if is_mountain:
		return  # Mountains keep their gray color
	# POIs now get region colors (no special coloring)
	node_color = color
	modulate = color

func set_mountain_color():
	# Mountain color: use node color #967b4c
	node_color = Color(0.588, 0.482, 0.298)  # #967b4c - Node color
	modulate = node_color

func become_mountain():
	# Called when this node is designated as a mountain
	# Randomize the sprite frame based on available hframes
	sprite_base.visible = false
	sprite_mountain.visible = true
	sprite_mountain.frame = randi() % sprite_mountain.hframes

func _on_button_pressed() -> void:
	# Emit signal to notify MapGenerator2D
	node_clicked.emit(self)


func _on_button_mouse_entered() -> void:
	node_hovered.emit(self)

func _on_button_mouse_exited() -> void:
	node_hover_ended.emit(self)
