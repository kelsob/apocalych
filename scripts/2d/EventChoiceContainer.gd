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

## Emitted once when any choice in this group is selected.
## outcome_text is non-empty when the choice used a probabilistic outcomes array.
signal choice_resolved(choice_id: String, effects: Array, outcome_text: String, next_step: Dictionary)
signal intro_done

## Seconds between each choice fading in. Set by EventLog.
var choice_stagger: float = 0.05
## Duration of each individual choice fade. Set by EventLog.
var choice_fade_duration: float = 0.10

func _ready():
	visible = false
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
	node.choice_selected.connect(_on_choice_selected.bind(node))
	_choice_nodes.append(node)
	vbox.add_child(node)

## JSON sometimes uses a single effect object instead of an array — normalize so EventLog can iterate.
func _coerce_effects_array(raw: Variant) -> Array:
	if raw is Array:
		return raw
	if raw is Dictionary:
		return [raw]
	if raw == null:
		return []
	push_warning("EventChoiceContainer: 'effects' must be an array or object, got type %s — using empty" % typeof(raw))
	return []

func _on_choice_selected(choice: Dictionary, source_node: EventChoice):
	if _resolved:
		return
	_resolved = true
	var choice_id: String = choice.get("id", "")
	for choice_node in _choice_nodes:
		if choice_node.choice_data.get("id", "") == choice_id:
			choice_node.select()
		else:
			choice_node.reject()

	var effects: Array = []
	var outcome_text: String = ""
	var next_step: Dictionary = {}

	var sc: Variant = choice.get("stat_challenge", {})
	if sc is Dictionary and not sc.is_empty():
		var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
		var members: Array = main.current_party_members if main and "current_party_members" in main else []
		var actor_slot: int = 0
		if source_node and source_node.has_method("get_stat_actor_slot_for_resolution"):
			actor_slot = int(source_node.call("get_stat_actor_slot_for_resolution"))
		var res: Dictionary = EventStatCheck.resolve_stat_challenge(choice, actor_slot, members, EventManager.rng)
		effects = _coerce_effects_array(res.get("effects", []))
		outcome_text = str(res.get("text", ""))
		EventManager.stat_check_context = {
			"actor_index": int(res.get("actor_index", 0)),
			"actor_name": str(res.get("actor_name", "")),
			"tier": str(res.get("tier", "")),
		}
	elif choice.has("outcomes") and choice.outcomes is Array and not choice.outcomes.is_empty():
		var outcome: Dictionary = EventManager.pick_weighted_outcome(choice.outcomes)
		effects = _coerce_effects_array(outcome.get("effects", []))
		outcome_text = outcome.get("text", "")
	elif choice.get("weighted_branches") is Array and not choice.weighted_branches.is_empty():
		next_step = EventManager.pick_weighted_branches(choice.weighted_branches)
	elif choice.has("then") and choice.then is Dictionary and not choice.then.is_empty():
		next_step = choice.then.duplicate(true)
	else:
		effects = _coerce_effects_array(choice.get("effects", []))

	choice_resolved.emit(choice_id, effects, outcome_text, next_step)

## Enable or disable all unresolved choice buttons (used to gate Continue behind item rewards).
func set_all_disabled(disabled: bool) -> void:
	for choice_node in _choice_nodes:
		if choice_node.button:
			choice_node.button.disabled = disabled

## Gray out all choices without resolving (called by EventLog.close() on external interrupt)
func reject_all():
	if _resolved:
		return
	_resolved = true
	for choice_node in _choice_nodes:
		choice_node.reject()

## Staggered fade-in of all choices. Awaitable — resolves when the last choice finishes fading.
func animate_in() -> void:
	visible = true
	for i in _choice_nodes.size():
		_choice_nodes[i].animate_in(i * choice_stagger, choice_fade_duration)
	var total_wait: float = 0.0
	if not _choice_nodes.is_empty():
		total_wait = (_choice_nodes.size() - 1) * choice_stagger + choice_fade_duration
	await get_tree().create_timer(total_wait).timeout
	intro_done.emit()

## Snap all choices to fully visible immediately, resolving any in-flight animate_in await.
func snap_visible() -> void:
	visible = true
	for choice_node in _choice_nodes:
		choice_node.snap_visible()
	intro_done.emit()

## Lock or unlock choice buttons for input (used during intro animation).
## Does not touch the disabled state of natively-disabled choices (requires_item, etc.).
func set_anim_locked(locked: bool) -> void:
	for cn in _choice_nodes:
		if cn.button:
			cn.button.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
