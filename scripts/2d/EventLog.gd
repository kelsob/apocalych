extends Control
class_name EventLog

## EventLog - Persistent scrollable log of all events that have occurred in the game.
## New events are appended as title/body/choice-container scene instances - nothing is ever purged.
## Scene expects:
##   $ScrollContainer                   (ScrollContainer)
##   $ScrollContainer/LogContainer      (VBoxContainer - the append target)

@onready var scroll_container: ScrollContainer = $MarginContainer/MarginContainer/ScrollContainer
@onready var log_container: VBoxContainer = $MarginContainer/MarginContainer/ScrollContainer/ContentContainer
@onready var visibility_spacer: Control = $MarginContainer/MarginContainer/ScrollContainer/ContentContainer/VisibilitySpacer

var _event_title_scene: PackedScene = null
var _event_body_scene: PackedScene = null
var _event_rewards_scene: PackedScene = null
var _event_choice_container_scene: PackedScene = null
var _event_separator_scene: PackedScene = null
var _item_reward_scene: PackedScene = null
var _item_choice_reward_scene: PackedScene = null
var _trait_reward_scene: PackedScene = null

# Reference to the active (unresolved) choice container - cleared once resolved
var _active_choice_container: EventChoiceContainer = null

# True after the first event has been appended - used to gate separator insertion
var _log_has_content: bool = false

# State for the in-flight event (needed for combat_outcomes stash)
var _current_event: Dictionary = {}
var _current_party: Dictionary = {}
var _current_node = null

# True while waiting for the player to select a choice
var _awaiting_choice: bool = false

@export_group("Panel Animation")
@export var anim_open_duration: float = 0.15
@export var anim_close_duration: float = 0.12

@export_group("Content Intro Animation")
@export var anim_title_duration: float = 0.10
@export var anim_body_typewriter_chars_per_second: float = 60.0
@export var anim_choice_stagger: float = 0.05
@export var anim_choice_fade_duration: float = 0.10

var _anim_tween: Tween = null

# Content intro animation state
var _intro_animating: bool = false
var _intro_nodes: Array = []

# Outcome narrative body (after a choice) — EventLog _input snaps this while it typewrites
var _skippable_outcome_body: EventBody = null

signal choice_made(choice_id: String, effects: Array, outcome_text: String)
signal event_closed()

func _ready():
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE
	# Process input early so we can skip typewriters before deeper controls eat the click.
	process_priority = -1000
	_update_eventlog_input_processing()

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

	_item_reward_scene = load("res://scenes/2d/ItemReward.tscn")
	if not _item_reward_scene:
		push_error("EventLog: Could not load ItemReward scene")

	_item_choice_reward_scene = load("res://scenes/2d/ItemChoiceReward.tscn")
	if not _item_choice_reward_scene:
		push_error("EventLog: Could not load ItemChoiceReward scene")

	_trait_reward_scene = load("res://scenes/2d/TraitReward.tscn")
	if not _trait_reward_scene:
		push_error("EventLog: Could not load TraitReward scene")

	# Scroll to bottom whenever the log becomes visible
	visibility_changed.connect(_on_visibility_changed)

	# Scroll to bottom whenever the log container re-sorts its children.
	# This fires when any child's visible property changes or a child is added,
	# keeping the view pinned to the spacer throughout all animations.
	log_container.sort_children.connect(
		func(): scroll_container.ensure_control_visible.call_deferred(visibility_spacer)
	)

func _update_eventlog_input_processing() -> void:
	set_process_input(visible)
	set_process_unhandled_input(visible)


func _can_skip_text_animation() -> bool:
	if _intro_animating:
		return true
	if _skippable_outcome_body != null and is_instance_valid(_skippable_outcome_body) and _skippable_outcome_body.is_typewriter_active():
		return true
	return false


func _try_skip_text_animation_mouse(global_pos: Vector2) -> void:
	if not visible or not _can_skip_text_animation():
		return
	if not get_global_rect().has_point(global_pos):
		return
	if _intro_animating:
		_skip_intro()
	elif _skippable_outcome_body != null and is_instance_valid(_skippable_outcome_body):
		_skippable_outcome_body.snap_visible()
	get_viewport().set_input_as_handled()


func _try_skip_text_animation_ui_accept() -> void:
	if not visible or not _can_skip_text_animation():
		return
	if _intro_animating:
		_skip_intro()
	elif _skippable_outcome_body != null and is_instance_valid(_skippable_outcome_body):
		_skippable_outcome_body.snap_visible()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_skip_text_animation_mouse(event.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_echo():
		return
	if Input.is_action_just_pressed("ui_accept"):
		_try_skip_text_animation_ui_accept()

func _on_visibility_changed():
	_update_eventlog_input_processing()
	if visible and is_instance_valid(visibility_spacer):
		await get_tree().process_frame
		scroll_container.ensure_control_visible(visibility_spacer)

## Append a new event to the log. Main entry point called by Main.
## event: pre-processed event dict from EventManager.present_event() (`immediate_effects` already applied there)
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

	var title_node: EventTitle = _append_title(event.get("title", "Event"))

	var body_text: String = event.get("text", "")
	var body_node: EventBody = null
	if not body_text.is_empty():
		body_node = _append_body(body_text)

	var rewards: Dictionary = event.get("rewards", {})
	if not rewards.is_empty():
		_append_rewards(rewards)

	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		choices = [_create_default_continue_choice()]

	var choice_node: EventChoiceContainer = _append_choice_container(choices)

	_awaiting_choice = true
	_pause_gameplay()

	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	_play_intro_sequence(title_node, body_node, choice_node)

## Ensures VisibilitySpacer is always the final child so scrolling to it shows the log bottom.
func _push_spacer_to_end() -> void:
	if is_instance_valid(visibility_spacer):
		log_container.move_child(visibility_spacer, -1)

## Append a visual separator between events
func _append_separator():
	if not _event_separator_scene:
		return
	var separator = _event_separator_scene.instantiate()
	log_container.add_child(separator)
	_push_spacer_to_end()

## Append a title element to the log
func _append_title(text: String) -> EventTitle:
	if not _event_title_scene:
		return null
	var title_node: EventTitle = _event_title_scene.instantiate()
	title_node.set_title(text)
	log_container.add_child(title_node)
	_push_spacer_to_end()
	return title_node

## Append a body element to the log
func _append_body(text: String) -> EventBody:
	if not _event_body_scene:
		return null
	var body_node: EventBody = _event_body_scene.instantiate()
	body_node.set_body(text)
	log_container.add_child(body_node)
	_push_spacer_to_end()
	return body_node

## Append a rewards display block (XP and gold earned)
func _append_rewards(rewards: Dictionary):
	if not _event_rewards_scene:
		return
	var rewards_node: EventRewards = _event_rewards_scene.instantiate()
	rewards_node.set_rewards(rewards)
	log_container.add_child(rewards_node)
	_push_spacer_to_end()

## Flatten effects from choice-level and every outcome (for preview / label substitution only).
func _flatten_choice_effects_for_preview(choice: Dictionary) -> Array:
	var out: Array = []
	var top: Variant = choice.get("effects", [])
	if top is Array:
		for e in top:
			out.append(e)
	var outs: Variant = choice.get("outcomes", [])
	if outs is Array:
		for o in outs:
			if o is Dictionary:
				var es: Variant = o.get("effects", [])
				if es is Array:
					for e in es:
						out.append(e)
	return out

## Replace {slot0}, {slot1}, … with live party member names (Main.current_party_members order).
func _substitute_slot_placeholders_in_string(text: String) -> String:
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	if not main:
		return text
	var members: Array = main.current_party_members
	for i in members.size():
		text = text.replace("{slot%d}" % i, members[i].member_name)
	return text

## If this effect is give_trait with a single known recipient, return their display name for choice labels.
func _preview_member_name_from_give_trait_effect(effect: Dictionary) -> String:
	if effect.get("type") != "give_trait":
		return ""
	var mn: String = str(effect.get("member_name", "")).strip_edges()
	if not mn.is_empty():
		return mn
	var target: Variant = effect.get("target", "random")
	var ts: String = str(target)
	if ts == "all" or ts == "random" or ts == "acted":
		return ""
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	if not main:
		return ""
	var idx: int = -1
	if typeof(target) == TYPE_INT:
		idx = target
	elif typeof(target) == TYPE_FLOAT:
		var f: float = target
		if is_equal_approx(f, roundf(f)):
			idx = int(f)
	elif typeof(target) == TYPE_STRING:
		var s: String = str(target)
		if s.is_valid_int():
			idx = int(s)
	if idx >= 0 and idx < main.current_party_members.size():
		return main.current_party_members[idx].member_name
	return ""

## First single-recipient give_trait in this choice (effects + outcomes) drives {member} in the choice button text.
func _preview_member_name_for_choice_label(choice: Dictionary) -> String:
	for eff in _flatten_choice_effects_for_preview(choice):
		if eff is Dictionary:
			var name: String = _preview_member_name_from_give_trait_effect(eff)
			if not name.is_empty():
				return name
	return ""

## Deep-copy a choice and resolve {slotN} / {member} for on-screen button labels (EventManager.text_vars is still empty here).
func _prepare_choice_dict_for_display(choice: Dictionary) -> Dictionary:
	var c: Dictionary = choice.duplicate(true)
	var t: String = str(c.get("text", ""))
	t = _substitute_slot_placeholders_in_string(t)
	var preview: String = _preview_member_name_for_choice_label(c)
	if not preview.is_empty():
		t = t.replace("{member}", preview)
	c["text"] = t
	return c

## Append a choice container holding all choices for this event
func _append_choice_container(choices: Array) -> EventChoiceContainer:
	if not _event_choice_container_scene:
		return null
	var container: EventChoiceContainer = _event_choice_container_scene.instantiate()
	var display_choices: Array = []
	for ch in choices:
		if ch is Dictionary:
			display_choices.append(_prepare_choice_dict_for_display(ch))
		else:
			display_choices.append(ch)
	container.populate_choices(display_choices)
	container.choice_resolved.connect(_on_choice_resolved)
	_active_choice_container = container
	log_container.add_child(container)
	_push_spacer_to_end()
	return container

## Creates and adds an ItemReward node to the log. Returns it so the caller can await member_chosen.
## Returns null if the scene is missing or the party is empty.
func _spawn_item_reward_node(reward: Dictionary) -> ItemReward:
	if not _item_reward_scene:
		push_warning("EventLog: _item_reward_scene is null — ItemReward.tscn not loaded")
		return null
	var main = get_tree().get_first_node_in_group("main") if get_tree() else null
	var members: Array = main.current_party_members if main else []
	if members.is_empty():
		push_warning("EventLog: no party members, cannot present item reward")
		return null
	var reward_node: ItemReward = _item_reward_scene.instantiate()
	log_container.add_child(reward_node)
	_push_spacer_to_end()
	reward_node.setup(reward.item, reward.count, members)
	reward_node.visible = false
	return reward_node

## Creates and adds an ItemChoiceReward node for grant:"one" sets.
## Returns null if the scene is missing, items list is empty, or party is empty.
func _spawn_item_choice_node(items: Array) -> ItemChoiceReward:
	if not _item_choice_reward_scene:
		push_warning("EventLog: _item_choice_reward_scene is null — ItemChoiceReward.tscn not loaded")
		return null
	if items.is_empty():
		return null
	var main = get_tree().get_first_node_in_group("main") if get_tree() else null
	var members: Array = main.current_party_members if main else []
	if members.is_empty():
		push_warning("EventLog: no party members, cannot present item choice")
		return null
	var node: ItemChoiceReward = _item_choice_reward_scene.instantiate()
	log_container.add_child(node)
	_push_spacer_to_end()
	node.setup(items, members)
	node.visible = false
	return node

## Spawn read-only TraitReward rows for each give_trait in this effect list. Inserts after outcome body (or before VisibilitySpacer).
func _spawn_trait_reward_displays_for_effects(effects: Variant, insert_after: Control) -> Array:
	var result: Array = []
	if not _trait_reward_scene:
		push_warning("EventLog: TraitReward.tscn failed to load — check res://scenes/2d/TraitReward.tscn")
		return result
	var fx: Array = []
	if effects is Array:
		fx = effects
	elif effects is Dictionary:
		fx = [effects]
	if fx.is_empty():
		return result
	var insert_idx: int = 0
	if insert_after and is_instance_valid(insert_after):
		insert_idx = insert_after.get_index() + 1
	elif is_instance_valid(visibility_spacer):
		insert_idx = visibility_spacer.get_index()
	else:
		insert_idx = log_container.get_child_count()
	var give_trait_seen: int = 0
	for eff in fx:
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		if str(eff.get("type", "")) != "give_trait":
			continue
		give_trait_seen += 1
		var tid: String = str(eff.get("trait_id", ""))
		if tid.is_empty():
			push_warning("EventLog: give_trait effect missing trait_id")
			continue
		if not TraitDatabase.has_trait(tid):
			push_warning("EventLog: TraitReward not spawned — TraitDatabase has no trait '%s'" % tid)
			continue
		var inst: Node = _trait_reward_scene.instantiate()
		if not (inst is TraitReward):
			push_error("EventLog: TraitReward.tscn root must use TraitReward.gd (class_name TraitReward)")
			inst.queue_free()
			continue
		var row: TraitReward = inst
		log_container.add_child(row)
		var to_idx: int = clampi(insert_idx, 0, maxi(log_container.get_child_count() - 1, 0))
		log_container.move_child(row, to_idx)
		insert_idx = row.get_index() + 1
		row.setup(TraitDatabase.get_trait(tid))
		row.visible = false
		result.append(row)
	_push_spacer_to_end()
	if give_trait_seen > 0 and result.is_empty():
		push_warning("EventLog: had give_trait in effects but spawned 0 TraitReward rows (scene/type/DB issue)")
	return result

## Quick fade-in without awaiting — does not block Continue or item flows.
func _reveal_trait_row_fade_fire_and_forget(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.visible = true
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Sequential item reward for the no-outcome-text path: spawn, await selection, fulfill.
func _present_item_reward(reward: Dictionary) -> void:
	var rn := _spawn_item_reward_node(reward)
	if not rn:
		return
	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)
	var chosen: PartyMember = await rn.member_chosen
	EventManager.fulfill_item_reward(reward.item_id, reward.count, chosen)

## Called when the active choice container resolves a player choice.
## outcome_text is non-empty when the choice used a probabilistic outcomes pool.
func _on_choice_resolved(choice_id: String, effects: Array, outcome_text: String):
	if not _awaiting_choice:
		return
	_awaiting_choice = false

	# Collect continue containers to free after the close animation — not before.
	var _deferred_free: Array = []

	# Default no-choice continue: defer cleanup until after hide animation
	if choice_id == "continue" and _active_choice_container and is_instance_valid(_active_choice_container):
		_deferred_free.append(_active_choice_container)
	_active_choice_container = null

	choice_made.emit(choice_id, effects, outcome_text)

	# Helper to apply effects and extract pending item reward entries.
	var _apply_and_drain := func() -> Array:
		if not (EventManager and effects.size() > 0):
			return []
		var node_state: Dictionary = {}
		if _current_node:
			node_state["current_node"] = _current_node
		for effect in effects:
			if effect.get("type") == "start_combat":
				EventManager.pending_combat_outcomes = _current_event.get("combat_outcomes", {}).duplicate(true)
				break
		EventManager.apply_effects(effects, _current_party, node_state)
		var entries: Array = []
		for reward in EventManager.drain_pending_item_rewards():
			var rn := _spawn_item_reward_node(reward)
			if rn:
				entries.append({ "type": "item_reward", "node": rn, "reward": reward })
		for choice_set in EventManager.drain_pending_item_choices():
			var cn := _spawn_item_choice_node(choice_set.get("items", []))
			if cn:
				entries.append({ "type": "item_choice", "node": cn })
		return entries

	if not outcome_text.is_empty():
		# Apply effects first so text_vars are populated before we display the body.
		var item_entries: Array = _apply_and_drain.call()

		var body_node: EventBody = _append_body(_substitute_text_vars(outcome_text))
		var trait_info_nodes: Array = _spawn_trait_reward_displays_for_effects(effects, body_node)

		# Continue button — added to the tree now so it sits below items, but stays hidden
		# until after items are revealed.
		var continue_container: EventChoiceContainer = _event_choice_container_scene.instantiate()
		continue_container.populate_choices([_create_default_continue_choice()])
		_active_choice_container = continue_container
		log_container.add_child(continue_container)
		_push_spacer_to_end()
		# Must disable AFTER add_child so _ready() has populated _choice_nodes.
		if not item_entries.is_empty():
			continue_container.set_all_disabled(true)
		_awaiting_choice = true

		await get_tree().process_frame
		scroll_container.ensure_control_visible(visibility_spacer)

		# Animate outcome text in first (skip: any click / ui_accept anywhere on EventLog rect — see _input).
		if body_node:
			body_node.typewriter_chars_per_second = anim_body_typewriter_chars_per_second
			_skippable_outcome_body = body_node
			await body_node.animate_in()
			_skippable_outcome_body = null

		# Trait info cards: fire-and-forget fade; Continue is not gated on these (only on item UIs).
		for tr in trait_info_nodes:
			_reveal_trait_row_fade_fire_and_forget(tr)
		await get_tree().process_frame
		scroll_container.ensure_control_visible(visibility_spacer)

		# Reveal item nodes sequentially with quick fades.
		for entry in item_entries:
			await _reveal_entry_node(entry)
			scroll_container.ensure_control_visible(visibility_spacer)

		# Reveal the continue container after items are all visible.
		continue_container.animate_in()

		# Resolve each item in sequence (player interacts), then unlock Continue.
		for entry in item_entries:
			await _present_item_reward_entry(entry)

		if not item_entries.is_empty():
			continue_container.set_all_disabled(false)

		await continue_container.choice_resolved
		_awaiting_choice = false
		_active_choice_container = null
		_deferred_free.append(continue_container)

	else:
		# No outcome text: apply effects, show trait info rows (no body to insert after), then items.
		var item_entries_else: Array = _apply_and_drain.call()
		for tr in _spawn_trait_reward_displays_for_effects(effects, null):
			_reveal_trait_row_fade_fire_and_forget(tr)
		await get_tree().process_frame
		scroll_container.ensure_control_visible(visibility_spacer)
		for entry in item_entries_else:
			await _reveal_entry_node(entry)
			await _present_item_reward_entry(entry)

	_resume_gameplay()
	await _hide_animated()

	for node in _deferred_free:
		if is_instance_valid(node):
			node.queue_free()

	event_closed.emit()

## Quick fade-in for a spawned item reward or choice node.
func _reveal_entry_node(entry: Dictionary) -> void:
	var node: Control = entry.node
	if not is_instance_valid(node):
		return
	node.visible = true
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

## Awaits a pre-spawned item reward or item choice node and fulfills the grant.
func _present_item_reward_entry(entry: Dictionary) -> void:
	# Ensure visible in case _reveal_entry_node was not called for this entry.
	if is_instance_valid(entry.node) and not entry.node.visible:
		entry.node.visible = true
		entry.node.modulate.a = 1.0
	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	if entry.get("type") == "item_choice":
		await entry.node.resolved
		var item_id: String = entry.node.chosen_item_data.get("item_id", "")
		var count: int = entry.node.chosen_item_data.get("count", 1)
		EventManager.fulfill_item_reward(item_id, count, entry.node.chosen_member)
	else:
		var chosen: PartyMember = await entry.node.member_chosen
		EventManager.fulfill_item_reward(entry.reward.item_id, entry.reward.count, chosen)

## Replace {key} placeholders in text with values from EventManager.text_vars.
func _substitute_text_vars(text: String) -> String:
	for key in EventManager.text_vars:
		text = text.replace("{%s}" % key, str(EventManager.text_vars[key]))
	return text

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

## Fire-and-forget intro sequence: title → body → choices, each with its own animation.
## Choice buttons are input-locked until the sequence finishes or is skipped.
func _play_intro_sequence(title_node: EventTitle, body_node: EventBody, choice_node: EventChoiceContainer) -> void:
	if not title_node:
		return
	_intro_animating = true
	_intro_nodes.clear()
	if title_node: _intro_nodes.append(title_node)
	if body_node: _intro_nodes.append(body_node)
	if choice_node: _intro_nodes.append(choice_node)

	title_node.duration = anim_title_duration
	if body_node:
		body_node.typewriter_chars_per_second = anim_body_typewriter_chars_per_second
	if choice_node:
		choice_node.choice_stagger = anim_choice_stagger
		choice_node.choice_fade_duration = anim_choice_fade_duration
		choice_node.set_anim_locked(true)

	await title_node.animate_in()

	if _intro_animating and body_node and is_instance_valid(body_node):
		await body_node.animate_in()

	if _intro_animating and choice_node and is_instance_valid(choice_node):
		await choice_node.animate_in()

	_finish_intro()

## Called after intro completes normally or is skipped.
func _finish_intro() -> void:
	_intro_animating = false
	_intro_nodes.clear()
	if _active_choice_container:
		_active_choice_container.set_anim_locked(false)

## Snap all intro elements to their final state and immediately unlock choices.
func _skip_intro() -> void:
	if not _intro_animating:
		return
	for node in _intro_nodes:
		if is_instance_valid(node):
			node.snap_visible()
	_finish_intro()

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
	_update_eventlog_input_processing()

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
	_update_eventlog_input_processing()

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
