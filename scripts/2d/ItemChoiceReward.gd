extends Control
class_name ItemChoiceReward

## ItemChoiceReward — Presents multiple item options as ItemReward nodes side by side.
## The player picks a member button under any item to claim it in one step.
## The other options are dismissed. EventLog reads chosen_item_data + chosen_member
## and calls fulfill_item_reward directly.
##
## Expected scene structure (ItemChoiceReward.tscn):
##   ItemChoiceReward (Control, root — attach this script)
##   └── VBoxContainer
##       ├── PromptLabel      (Label — "Choose one item:")
##       └── OptionsContainer (HBoxContainer — ItemReward instances added at runtime)

@onready var options_container: VBoxContainer = $OptionsContainer

signal resolved

var _item_reward_scene: PackedScene = preload("res://scenes/2d/ItemReward.tscn")
var _resolved: bool = false
var _reward_nodes: Array = []

## Populated when resolved — read by EventLog to fulfill the grant.
var chosen_item_data: Dictionary = {}
var chosen_member: HeroCharacter = null

## items: array of {item_id, count, item}. members: current party members array.
func setup(items: Array, members: Array) -> void:
	for item_data in items:
		var node: ItemReward = _item_reward_scene.instantiate()
		options_container.add_child(node)
		node.setup(item_data.item, item_data.get("count", 1), members)
		node.member_chosen.connect(_on_member_chosen.bind(item_data, node))
		_reward_nodes.append(node)

func _on_member_chosen(member: HeroCharacter, item_data: Dictionary, source_node: ItemReward) -> void:
	if _resolved:
		return
	_resolved = true
	chosen_item_data = item_data
	chosen_member = member
	# Dismiss all other options
	for node in _reward_nodes:
		if is_instance_valid(node) and node != source_node:
			node.queue_free()
	resolved.emit()
