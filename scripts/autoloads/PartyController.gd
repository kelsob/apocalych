extends Node

## Party Controller - Manages party state and position on the map
## Autoload singleton for global party management

signal party_moved(from_node: MapNode2D, to_node: MapNode2D)
signal party_spawned(node: MapNode2D)

# Current node the party is on
var current_node: MapNode2D = null

# Reference to the map generator (set after map generation)
var map_generator: MapGenerator2D = null

func _ready():
	print("PartyController initialized")

## Spawn the party at a random node on the map
func spawn_party_at_random_node(map_gen: MapGenerator2D):
	map_generator = map_gen
	
	if not map_generator or map_generator.map_nodes.size() == 0:
		push_error("PartyController: Cannot spawn party - no map nodes available")
		return
	
	# Filter out mountain nodes (party can't spawn on mountains)
	var valid_nodes: Array[MapNode2D] = []
	for node in map_generator.map_nodes:
		if not node.is_mountain:
			valid_nodes.append(node)
	
	if valid_nodes.size() == 0:
		push_error("PartyController: No valid nodes to spawn party (all are mountains?)")
		return
	
	# Pick a random valid node
	var spawn_node = valid_nodes[randi() % valid_nodes.size()]
	move_party_to_node(spawn_node)
	
	print("Party spawned at node %d" % spawn_node.node_index)
	party_spawned.emit(spawn_node)

## Move party to a specific node
func move_party_to_node(node: MapNode2D):
	if not node:
		push_error("PartyController: Cannot move party to null node")
		return
	
	var previous_node = current_node
	current_node = node
	
	# Update visual representation
	if previous_node:
		previous_node.set_party_present(false)
	
	node.set_party_present(true)
	
	if previous_node:
		party_moved.emit(previous_node, current_node)
	
	print("Party moved to node %d" % node.node_index)

## Get the current node the party is on
func get_current_node() -> MapNode2D:
	return current_node

## Check if party can move to a node (must be connected to current node)
func can_move_to_node(node: MapNode2D) -> bool:
	if not current_node:
		return false
	
	if not node:
		return false
	
	# Can't move to mountains
	if node.is_mountain:
		return false
	
	# Must be connected to current node
	return current_node.is_connected_to(node)

## Get all nodes the party can move to from current position
func get_available_moves() -> Array[MapNode2D]:
	if not current_node:
		return []
	
	var available: Array[MapNode2D] = []
	for neighbor in current_node.connections:
		if not neighbor.is_mountain:
			available.append(neighbor)
	
	return available
