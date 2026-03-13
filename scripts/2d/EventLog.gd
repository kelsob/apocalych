extends Control
class_name EventLog

## EventLog - Persistent scrollable log of all events that have occurred in the game.
## New events are appended as title/body/choice-container scene instances - nothing is ever purged.
## Scene expects:
##   $ScrollContainer                   (ScrollContainer)
##   $ScrollContainer/LogContainer      (VBoxContainer - the append target)

@onready var scroll_container: ScrollContainer = $MarginContainer/MarginContainer/ScrollContainer
@onready var log_container: VBoxContainer = $MarginContainer/MarginContainer/ScrollContainer/ContentContainer

var _event_title_scene: PackedScene = null
var _event_body_scene: PackedScene = null
var _event_rewards_scene: PackedScene = null
var _event_choice_container_scene: PackedScene = null
var _event_separator_scene: PackedScene = null

# Reference to the active (unresolved) choice container - cleared once resolved
var _active_choice_container: EventChoiceContainer = null

# The most recently appended node - used for ensure_control_visible
var _last_appended_node: Control = null

# True after the first event has been appended - used to gate separator insertion
var _log_has_content: bool = false

# State for the in-flight event (needed for combat_outcomes stash)
var _current_event: Dictionary = {}
var _current_party: Dictionary = {}
var _current_node = null

# True while waiting for the player to select a choice
var _awaiting_choice: bool = false

# Animation
@export var anim_open_duration: float = 0.15
@export var anim_close_duration: float = 0.12
var _anim_tween: Tween = null

signal choice_made(choice_id: String, effects: Array)
signal event_closed()

func _ready():
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE

	_event_title_scene = load("res://scenes/2d/EventTitle.tscn")
	if not _event_title_scene:
		push_error("EventLog: Could not load EventTitle scene")

	_event_body_scene = load("res://scenes/2d/EventBody.tscn")
	if not _event_body_scene:
		push_error("EventLog: Could not load EventBody scene")

	_event_rewards_scene = load("res://scenes/2d/EventRewards.tscn")
	if not _event_rewards_scene:
		push_error("EventLog: Could not load EventRewards scene")

	_event_choice_container_scene = load("res://scenes/2d/EventChoiceContainer.tscn")
	if not _event_choice_container_scene:
		push_error("EventLog: Could not load EventChoiceContainer scene")

	_event_separator_scene = load("res://scenes/2d/EventSeparator.tscn")
	if not _event_separator_scene:
		push_error("EventLog: Could not load EventSeparator scene")

	# Scroll to bottom whenever the log becomes visible
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible and _last_appended_node and is_instance_valid(_last_appended_node):
		await get_tree().process_frame
		scroll_container.ensure_control_visible(_last_appended_node)

## Append a new event to the log. Main entry point called by Main.
## event: pre-processed event dict from EventManager.present_event()
## party: party state dict
## node: MapNode2D where the event is occurring (may be null)
func append_event(event: Dictionary, party: Dictionary, node = null):
	if event.is_empty():
		push_error("EventLog: Cannot append empty event")
		return

	_current_event = event
	_current_party = party
	_current_node = node
	_show_animated()

	var is_combat_outcome: bool = event.get("id", "") == "_combat_outcome"
	if _log_has_content and not is_combat_outcome:
		_append_separator()
	_log_has_content = true

	_append_title(event.get("title", "Event"))

	var body_text: String = event.get("text", "")
	if not body_text.is_empty():
		_append_body(body_text)

	var rewards: Dictionary = event.get("rewards", {})
	if not rewards.is_empty():
		_append_rewards(rewards)

	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		choices = [_create_default_continue_choice()]

	_append_choice_container(choices)

	_awaiting_choice = true
	_pause_gameplay()

	await get_tree().process_frame
	if _last_appended_node and is_instance_valid(_last_appended_node):
		scroll_container.ensure_control_visible(_last_appended_node)

## Append a visual separator between events
func _append_separator():
	if not _event_separator_scene:
		return
	var separator = _event_separator_scene.instantiate()
	log_container.add_child(separator)

## Append a title element to the log
func _append_title(text: String):
	if not _event_title_scene:
		return
	var title_node = _event_title_scene.instantiate()
	title_node.set_title(text)
	log_container.add_child(title_node)
	_last_appended_node = title_node

## Append a body element to the log
func _append_body(text: String):
	if not _event_body_scene:
		return
	var body_node = _event_body_scene.instantiate()
	body_node.set_body(text)
	log_container.add_child(body_node)
	_last_appended_node = body_node

## Append a rewards display block (XP and gold earned)
func _append_rewards(rewards: Dictionary):
	if not _event_rewards_scene:
		return
	var rewards_node: EventRewards = _event_rewards_scene.instantiate()
	rewards_node.set_rewards(rewards)
	log_container.add_child(rewards_node)
	_last_appended_node = rewards_node

## Append a choice container holding all choices for this event
func _append_choice_container(choices: Array):
	if not _event_choice_container_scene:
		return
	var container: EventChoiceContainer = _event_choice_container_scene.instantiate()
	container.populate_choices(choices)
	container.choice_resolved.connect(_on_choice_resolved)
	_active_choice_container = container
	log_container.add_child(container)
	_last_appended_node = container

## Called when the active choice container resolves a player choice
func _on_choice_resolved(choice_id: String, effects: Array):
	if not _awaiting_choice:
		return
	_awaiting_choice = false
	_active_choice_container = null

	choice_made.emit(choice_id, effects)

	if EventManager and effects.size() > 0:
		var node_state: Dictionary = {}
		if _current_node:
			node_state["current_node"] = _current_node
		for effect in effects:
			if effect.get("type") == "start_combat":
				EventManager.pending_combat_outcomes = _current_event.get("combat_outcomes", {}).duplicate(true)
				break
		EventManager.apply_effects(effects, _current_party, node_state)

	_resume_gameplay()
	await _hide_animated()
	event_closed.emit()

## Gracefully release any active choice lock and resume gameplay.
## Called when something external (vendor open, etc.) needs to interrupt.
## Does NOT clear the visual log - history is preserved.
func close():
	if _awaiting_choice and _active_choice_container:
		_active_choice_container.reject_all()
		_active_choice_container = null
		_awaiting_choice = false
	_resume_gameplay()
	await _hide_animated()
	event_closed.emit()

## Fallback choice when an event provides no choices
func _create_default_continue_choice() -> Dictionary:
	return {
		"id": "continue",
		"text": "Continue",
		"condition": {"requires_tags": [], "forbids_tags": []},
		"effects": [],
		"next_event": null,
		"weight": 1
	}

## Fade + scale in. Fire-and-forget (no await needed at call site).
func _show_animated() -> void:
	if _anim_tween:
		_anim_tween.kill()
	_set_map_zoom_disabled(true)
	pivot_offset = size / 2.0
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	visible = true
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(self, "modulate:a", 1.0, anim_open_duration)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, anim_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Fade + scale out. Awaitable — hides after animation completes.
func _hide_animated() -> void:
	if _anim_tween:
		_anim_tween.kill()
	pivot_offset = size / 2.0
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(self, "modulate:a", 0.0, anim_close_duration)
	_anim_tween.tween_property(self, "scale", Vector2(0.97, 0.97), anim_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE
	_set_map_zoom_disabled(false)

## Enable or disable map zoom via the camera group
func _set_map_zoom_disabled(disabled: bool) -> void:
	if not get_tree():
		return
	for cam in get_tree().get_nodes_in_group("map_camera"):
		cam.zoom_disabled = disabled

## Pause gameplay (disable map interaction while awaiting choice)
func _pause_gameplay():
	var main = get_tree().get_first_node_in_group("main") if get_tree() else null
	if main:
		var map_generator = main.get_node_or_null("MapGenerator")
		if map_generator:
			map_generator.events_paused = true
			map_generator.set_process_input(false)
			map_generator.set_process(false)
			map_generator._clear_hover_preview()

## Resume gameplay (re-enable map interaction after choice resolved)
func _resume_gameplay():
	var main = get_tree().get_first_node_in_group("main") if get_tree() else null
	if main:
		var map_generator = main.get_node_or_null("MapGenerator")
		if map_generator:
			map_generator.events_paused = false
			map_generator.set_process_input(true)
			map_generator.set_process(true)
