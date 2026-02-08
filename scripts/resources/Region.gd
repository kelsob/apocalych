extends Resource
class_name Region

## Region resource - represents a contiguous area of nodes with shared biome

# Core properties
var region_id: int = -1
var nodes: Array[MapNode2D] = []
var biome: Biome = null
var central_node: MapNode2D = null  # Node with highest regional centrality (lowest avg distance)
var randomized_center_position: Vector2 = Vector2.ZERO  # Offset center position for river convergence

# Border information
var border_nodes: Dictionary = {}  # Adjacent region_id -> Array[MapNode2D] (nodes on that border)
var adjacent_regions: Array[int] = []  # IDs of adjacent regions
var mountainous_borders: Dictionary = {}  # Adjacent region_id -> bool (is border mountainous?)

# Coastal information
var is_landlocked: bool = true
var coastal_nodes: Array[MapNode2D] = []

# River information (populated during generation)
var rivers: Array = []  # River data spawned in this region

func _init():
	pass

## Add a node to this region
func add_node(node: MapNode2D):
	if node not in nodes:
		nodes.append(node)

## Check if this region borders another region
func borders_region(other_region_id: int) -> bool:
	return other_region_id in adjacent_regions

## Get border nodes shared with a specific adjacent region
func get_border_with_region(other_region_id: int) -> Array[MapNode2D]:
	var result: Array[MapNode2D] = []
	if border_nodes.has(other_region_id):
		var nodes_array = border_nodes[other_region_id]
		for node in nodes_array:
			result.append(node)
	return result

## Check if border with specific region is mountainous
func is_border_mountainous(other_region_id: int) -> bool:
	return mountainous_borders.get(other_region_id, false)

## Get all mountainous borders (returns array of region IDs)
func get_mountainous_borders() -> Array[int]:
	var result: Array[int] = []
	for region_id in mountainous_borders.keys():
		if mountainous_borders[region_id]:
			result.append(region_id)
	return result

## Get count of mountainous borders
func get_mountainous_border_count() -> int:
	return get_mountainous_borders().size()
