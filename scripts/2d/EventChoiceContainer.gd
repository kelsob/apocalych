extends Control
class_name EventChoiceContainer

## EventChoiceContainer - Groups all choices for a single event entry in the EventLog.
## Instantiates EventChoice nodes into its VBoxContainer, handles select/reject logic,
## and emits one signal upward when the player resolves the group.
## Scene expects: $VBoxContainer (VBoxContainer - where EventChoice nodes are added)

@onready var vbox: VBoxContainer = $VBoxContainer

var _event_choice_scene: PackedScene = null
var _pending_choices: Array = []
var _choice_nodes: Array = []
var _resolved: bool = false

## Emitted once when any choice in this group is selected
signal choice_resolved(choice_id: String, effects: Array)

func _ready():
	_event_choice_scene = load("res://scenes/2d/EventChoice.tscn")
	if not _event_choice_scene:
		push_error("EventChoiceContainer: Could not load EventChoice scene")
		return
	for choice in _pending_choices:
		_create_choice_node(choice)
	_pending_choices.clear()

## Set the choices to display. Safe to call before the node is in the scene tree.
## If called after _ready, choices are created immediately.
func populate_choices(choices: Array):
	if is_inside_tree() and _event_choice_scene:
		for choice in choices:
			_create_choice_node(choice)
	else:
		_pending_choices = choices.duplicate()

func _create_choice_node(choice: Dictionary):
	var node = _event_choice_scene.instantiate()
	node.set_choice_data(choice)
	node.choice_selected.connect(_on_choice_selected)
	_choice_nodes.append(node)
	vbox.add_child(node)

func _on_choice_selected(choice: Dictionary):
	if _resolved:
		return
	_resolved = true
	var choice_id: String = choice.get("id", "")
	for choice_node in _choice_nodes:
		if choice_node.choice_data.get("id", "") == choice_id:
			choice_node.select()
		else:
			choice_node.reject()
	choice_resolved.emit(choice_id, choice.get("effects", []))

## Gray out all choices without resolving (called by EventLog.close() on external interrupt)
func reject_all():
	if _resolved:
		return
	_resolved = true
	for choice_node in _choice_nodes:
		choice_node.reject()
