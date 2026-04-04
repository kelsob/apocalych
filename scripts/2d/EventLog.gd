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

## When valid, `_on_choice_resolved` forwards `(choice_id, effects, outcome_text, next_step)` here and returns (nested step / Continue wait).
var _nested_choice_resume: Callable = Callable()

@export_group("Panel Animation")
@export var anim_open_duration: float = 0.15
@export var anim_close_duration: float = 0.12

@export_group("Content Intro Animation")
@export var anim_title_duration: float = 0.10
@export var anim_body_typewriter_chars_per_second: float = 60.0
@export var anim_choice_stagger: float = 0.05
@export var anim_choice_fade_duration: float = 0.10

var _anim_tween: Tween = null

# Segment text/choice animation (same for root event dict and every nested `then` step)
var _segment_animating: bool = false
var _segment_skip_nodes: Array = []

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
	if _segment_animating:
		return true
	if _skippable_outcome_body != null and is_instance_valid(_skippable_outcome_body) and _skippable_outcome_body.is_typewriter_active():
		return true
	return false


func _try_skip_text_animation_mouse(global_pos: Vector2) -> void:
	if not visible or not _can_skip_text_animation():
		return
	if not get_global_rect().has_point(global_pos):
		return
	if _segment_animating:
		_skip_segment_animation()
	elif _skippable_outcome_body != null and is_instance_valid(_skippable_outcome_body):
		_skippable_outcome_body.snap_visible()
	get_viewport().set_input_as_handled()


func _try_skip_text_animation_ui_accept() -> void:
	if not visible or not _can_skip_text_animation():
		return
	if _segment_animating:
		_skip_segment_animation()
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
## event: pre-processed event dict from EventManager.present_event() (`immediate_effects` applied there; their EventLog visuals queue with segment `rewards` and drain after title/body intro).
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

	_awaiting_choice = true
	_pause_gameplay()

	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	# Same code path as every nested `then` step: one `play_event` for title/body/effects/rewards/choices.
	# While `play_event` awaits the choice it uses `_nested_choice_resume`, so `_on_choice_resolved` only
	# fulfills that wait — the returned payload must be applied here (same as the non-resume branch).
	var payload: Dictionary = await play_event(event, false, "Event")
	var deferred_free: Array = []
	await _apply_resolved_choice_from_payload(payload, deferred_free)

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

## Segment `rewards` from JSON (same shape on the root event or any nested `then` step): enqueue one EventRewards row.
## Uses the same **`pending_event_log_visual_queue`** path as effect-driven gold/XP — no separate "top level" UI.
func _queue_segment_rewards_display(rewards: Dictionary) -> void:
	if not rewards is Dictionary or rewards.is_empty():
		return
	var xp: int = int(rewards.get("xp", 0))
	var gold: int = int(rewards.get("gold", 0))
	if xp <= 0 and gold <= 0:
		return
	EventManager.pending_event_log_visual_queue.append({ "kind": "rewards", "xp": xp, "gold": gold })


## Spawns EventRewards for drained queue entries: hidden until `_reveal_entry_node`, like ItemReward.
func _spawn_event_rewards_row_node(rewards: Dictionary) -> Control:
	if not _event_rewards_scene:
		return null
	var rewards_node: EventRewards = _event_rewards_scene.instantiate()
	rewards_node.set_rewards(rewards)
	log_container.add_child(rewards_node)
	_push_spacer_to_end()
	rewards_node.visible = false
	rewards_node.modulate.a = 0.0
	return rewards_node


func _node_state_for_effects() -> Dictionary:
	var node_state: Dictionary = {}
	if _current_node:
		node_state["current_node"] = _current_node
	return node_state


func _drain_pending_item_entries() -> Array:
	var entries: Array = []
	for raw in EventManager.drain_pending_event_log_visual_queue():
		if not raw is Dictionary:
			continue
		var kind: String = str(raw.get("kind", ""))
		match kind:
			"rewards":
				var xp: int = int(raw.get("xp", 0))
				var gold: int = int(raw.get("gold", 0))
				var rn := _spawn_event_rewards_row_node({ "xp": xp, "gold": gold })
				if rn:
					entries.append({ "type": "reward_display", "node": rn })
			"item":
				var reward: Variant = raw.get("reward", {})
				if reward is Dictionary:
					var rn2 := _spawn_item_reward_node(reward)
					if rn2:
						entries.append({ "type": "item_reward", "node": rn2, "reward": reward })
			"item_choice":
				var items: Array = raw.get("items", []) as Array
				var cn := _spawn_item_choice_node(items)
				if cn:
					entries.append({ "type": "item_choice", "node": cn })
	return entries


func _stash_combat_outcomes_if_needed(norm_effects: Array) -> void:
	for effect in norm_effects:
		if effect is Dictionary and str(effect.get("type", "")) == "start_combat":
			EventManager.pending_combat_outcomes = _current_event.get("combat_outcomes", {}).duplicate(true)
			break


## Flatten effects from choice-level and every outcome (for preview / label substitution only).
## Each dict is passed through EventManager.normalize_effect_for_apply so aliases match apply-time behavior.
func _flatten_choice_effects_for_preview(choice: Dictionary) -> Array:
	var out: Array = []
	var top: Variant = choice.get("effects", [])
	if top is Array:
		for e in top:
			if e is Dictionary:
				out.append(EventManager.normalize_effect_for_apply(e))
			else:
				out.append(e)
	var outs: Variant = choice.get("outcomes", [])
	if outs is Array:
		for o in outs:
			if o is Dictionary:
				var es: Variant = o.get("effects", [])
				if es is Array:
					for e in es:
						if e is Dictionary:
							out.append(EventManager.normalize_effect_for_apply(e))
						else:
							out.append(e)
	return out

## Replace {slot0}, {slot1}, … with live party member names (Main.run_roster order).
func _substitute_slot_placeholders_in_string(text: String) -> String:
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	if not main:
		return text
	var members: Array = main.run_roster
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
	if idx >= 0 and idx < main.run_roster.size():
		return main.run_roster[idx].member_name
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
	var members: Array = main.run_roster if main else []
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
	var members: Array = main.run_roster if main else []
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
	var chosen: HeroCharacter = await rn.member_chosen
	EventManager.fulfill_item_reward(reward.item_id, reward.count, chosen)

func _apply_effects_collect_items(norm_effects: Array) -> Array:
	if not (EventManager and norm_effects.size() > 0):
		return []
	var node_state: Dictionary = _node_state_for_effects()
	_stash_combat_outcomes_if_needed(norm_effects)
	EventManager.apply_effects(norm_effects, _current_party, node_state)
	return _drain_pending_item_entries()


func _close_event_session(deferred_free: Array) -> void:
	EventManager.drain_effects_on_event_close(_current_party, _node_state_for_effects())
	_resume_gameplay()
	await _hide_animated()
	for node in deferred_free:
		if is_instance_valid(node):
			node.queue_free()
	event_closed.emit()


## Outcome narrative + Continue (shared by root choice resolution and nested chain).
func _flow_outcome_text(norm_effects: Array, outcome_text: String, deferred_free: Array) -> void:
	var item_entries: Array = _apply_effects_collect_items(norm_effects)

	var body_node: EventBody = _append_body(_substitute_text_vars(outcome_text))
	var trait_info_nodes: Array = _spawn_trait_reward_displays_for_effects(norm_effects, body_node)

	var continue_container: EventChoiceContainer = _event_choice_container_scene.instantiate()
	continue_container.populate_choices([_create_default_continue_choice()])
	_active_choice_container = continue_container
	log_container.add_child(continue_container)
	_push_spacer_to_end()
	if not item_entries.is_empty():
		continue_container.set_all_disabled(true)
	_awaiting_choice = true

	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	if body_node:
		body_node.typewriter_chars_per_second = anim_body_typewriter_chars_per_second
		_skippable_outcome_body = body_node
		await body_node.animate_in()
		_skippable_outcome_body = null

	for tr in trait_info_nodes:
		_reveal_trait_row_fade_fire_and_forget(tr)
	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	for entry in item_entries:
		await _reveal_entry_node(entry)
		scroll_container.ensure_control_visible(visibility_spacer)

	continue_container.animate_in()

	for entry in item_entries:
		await _present_item_reward_entry(entry)

	if not item_entries.is_empty():
		continue_container.set_all_disabled(false)

	# Lambdas cannot assign outer locals — use a mutable dict for wait state.
	var cont_state: Dictionary = { "done": false }
	var cont_cb := func(_cid: String, _eff: Array, _ot: String, _ns: Dictionary) -> void:
		cont_state["done"] = true
	continue_container.choice_resolved.connect(cont_cb, Object.CONNECT_ONE_SHOT)
	while not bool(cont_state.get("done", false)):
		await get_tree().process_frame

	_awaiting_choice = false
	_active_choice_container = null
	deferred_free.append(continue_container)


## Root `text` is already interpolated in **`EventManager.present_event`** — pass **`apply_text_vars` = false** there.
## Nested steps use **`apply_text_vars` = true** so `_substitute_text_vars` runs on **`body`** / **`text`**.
func _segment_narrative_text(segment: Dictionary, apply_text_vars: bool) -> String:
	var raw: String = str(segment.get("body", segment.get("text", "")))
	if apply_text_vars:
		return _substitute_text_vars(raw)
	return raw


func _coerce_step_effects_array(step: Dictionary) -> Array:
	var raw: Variant = step.get("effects", [])
	if raw is Array:
		return raw
	if raw is Dictionary:
		return [raw]
	return []


## One event segment (root dict or any nested `then` step): phased effects, title/body/animate, rewards, choices, then `_nested_choice_resume`.
func play_event(segment: Dictionary, apply_text_vars: bool = true, default_title: String = "") -> Dictionary:
	var title_s: String = str(segment.get("title", ""))
	if title_s.is_empty() and not default_title.is_empty():
		title_s = default_title
	var body_s: String = _segment_narrative_text(segment, apply_text_vars)
	var choices: Array = segment.get("choices", []) as Array
	if not choices is Array:
		choices = []
	if choices.is_empty():
		choices = [_create_default_continue_choice()]

	var fx: Array = _coerce_step_effects_array(segment)
	var split: Dictionary = EventManager.ingest_effects_split_for_nested(fx)
	var before: Array = split.get("before", []) as Array
	var after: Array = split.get("after", []) as Array
	var node_state: Dictionary = _node_state_for_effects()
	_stash_combat_outcomes_if_needed(before)
	EventManager.apply_effects_array(before, _current_party, node_state)
	var entries_before: Array = _drain_pending_item_entries()

	var title_node: EventTitle = null
	if not title_s.is_empty():
		title_node = _append_title(title_s)
	var body_node: EventBody = null
	if not body_s.is_empty():
		body_node = _append_body(body_s)

	await _animate_segment_title_body_choices(title_node, body_node, null)

	var rewards_seg: Dictionary = segment.get("rewards", {})
	if rewards_seg is Dictionary and not rewards_seg.is_empty():
		_queue_segment_rewards_display(rewards_seg)
	var entries_segment_rewards: Array = _drain_pending_item_entries()
	for entry in entries_segment_rewards:
		await _reveal_entry_node(entry)
		await _present_item_reward_entry(entry)

	_stash_combat_outcomes_if_needed(after)
	EventManager.apply_effects_array(after, _current_party, node_state)
	var entries_after: Array = _drain_pending_item_entries()

	var norm_for_traits: Array = []
	for e in before:
		norm_for_traits.append(e)
	for e in after:
		norm_for_traits.append(e)
	var trait_nodes: Array = _spawn_trait_reward_displays_for_effects(norm_for_traits, body_node)

	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	for tr in trait_nodes:
		_reveal_trait_row_fade_fire_and_forget(tr)
	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)

	var all_entries: Array = entries_before + entries_after
	for entry in all_entries:
		await _reveal_entry_node(entry)
		scroll_container.ensure_control_visible(visibility_spacer)
	for entry in all_entries:
		await _present_item_reward_entry(entry)

	var choice_container: EventChoiceContainer = _append_choice_container(choices)
	choice_container.choice_stagger = anim_choice_stagger
	choice_container.choice_fade_duration = anim_choice_fade_duration
	choice_container.set_anim_locked(true)

	# Lambdas cannot assign outer locals — use a mutable dict for payload + wait state.
	var resume_state: Dictionary = {
		"done": false,
		"payload": {},
	}
	_nested_choice_resume = func(cid: String, eff: Array, ot: String, ns: Dictionary) -> void:
		resume_state["payload"] = {
			"choice_id": cid,
			"effects": eff,
			"outcome_text": ot,
			"next_step": ns,
		}
		resume_state["done"] = true

	_awaiting_choice = true
	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)
	# Same skip path as title/body animation: `_animate_segment_title_body_choices` uses `_segment_skip_nodes`.
	_segment_animating = true
	_segment_skip_nodes.clear()
	_segment_skip_nodes.append(choice_container)
	await choice_container.animate_in()
	_finish_segment_animation()

	while not bool(resume_state.get("done", false)):
		await get_tree().process_frame
	return resume_state.get("payload", {}) as Dictionary


func _run_nested_event_chain(first_step: Dictionary, deferred_free: Array) -> void:
	var current: Dictionary = first_step
	while not current.is_empty():
		var payload: Dictionary = await play_event(current, true, "")
		var resolved_id: String = str(payload.get("choice_id", ""))
		# Keep fork / branch choice rows in the log (persistent scroll). Only queue Continue
		# containers for cleanup when the event session ends — same idea as root outcome flow.
		if is_instance_valid(_active_choice_container):
			if resolved_id == "continue":
				deferred_free.append(_active_choice_container)
		_active_choice_container = null

		var norm_effects: Array = EventManager.normalize_effects_array(payload.get("effects", []))
		var outcome_text: String = str(payload.get("outcome_text", ""))
		var next_step: Dictionary = payload.get("next_step", {}) as Dictionary
		if not next_step is Dictionary:
			next_step = {}

		choice_made.emit(str(payload.get("choice_id", "")), norm_effects, outcome_text)

		if not outcome_text.is_empty():
			await _flow_outcome_text(norm_effects, outcome_text, deferred_free)
		else:
			if not norm_effects.is_empty():
				var item_entries: Array = _apply_effects_collect_items(norm_effects)
				for tr in _spawn_trait_reward_displays_for_effects(norm_effects, null):
					_reveal_trait_row_fade_fire_and_forget(tr)
				await get_tree().process_frame
				scroll_container.ensure_control_visible(visibility_spacer)
				for entry in item_entries:
					await _reveal_entry_node(entry)
					await _present_item_reward_entry(entry)

		if not next_step.is_empty():
			current = next_step
			continue
		break

	await _close_event_session(deferred_free)


## Called when the active choice container resolves a player choice.
## outcome_text is non-empty when the choice used a probabilistic outcomes pool.
func _on_choice_resolved(choice_id: String, effects: Array, outcome_text: String, next_step: Dictionary = {}):
	if _nested_choice_resume.is_valid():
		_awaiting_choice = false
		var cb: Callable = _nested_choice_resume
		_nested_choice_resume = Callable()
		cb.call(choice_id, effects, outcome_text, next_step)
		return

	if not _awaiting_choice:
		return
	_awaiting_choice = false

	var _deferred_free: Array = []
	await _apply_resolved_choice(choice_id, effects, outcome_text, next_step, _deferred_free)


## After any segment’s choice (root or nested): effects, optional outcome flow, `then` chain, close session.
func _apply_resolved_choice(choice_id: String, effects: Variant, outcome_text: String, next_step: Dictionary, deferred_free: Array) -> void:
	if choice_id == "continue" and _active_choice_container and is_instance_valid(_active_choice_container):
		deferred_free.append(_active_choice_container)
	_active_choice_container = null

	var raw_fx: Variant = effects
	if raw_fx is Dictionary:
		raw_fx = [raw_fx]
	if not raw_fx is Array:
		raw_fx = []
	var norm_effects: Array = EventManager.normalize_effects_array(raw_fx)
	choice_made.emit(choice_id, norm_effects, outcome_text)

	if not next_step.is_empty():
		await _run_nested_event_chain(next_step, deferred_free)
		return

	if not outcome_text.is_empty():
		await _flow_outcome_text(norm_effects, outcome_text, deferred_free)
		await _close_event_session(deferred_free)
		return

	var item_entries_else: Array = _apply_effects_collect_items(norm_effects)
	for tr in _spawn_trait_reward_displays_for_effects(norm_effects, null):
		_reveal_trait_row_fade_fire_and_forget(tr)
	await get_tree().process_frame
	scroll_container.ensure_control_visible(visibility_spacer)
	for entry in item_entries_else:
		await _reveal_entry_node(entry)
		await _present_item_reward_entry(entry)

	await _close_event_session(deferred_free)


func _apply_resolved_choice_from_payload(payload: Dictionary, deferred_free: Array) -> void:
	var ns: Variant = payload.get("next_step", {})
	var next_step: Dictionary = ns if ns is Dictionary else {}
	await _apply_resolved_choice(
		str(payload.get("choice_id", "")),
		payload.get("effects", []),
		str(payload.get("outcome_text", "")),
		next_step,
		deferred_free
	)

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
	if entry.get("type") == "reward_display":
		await get_tree().process_frame
		scroll_container.ensure_control_visible(visibility_spacer)
		return
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
		var chosen: HeroCharacter = await entry.node.member_chosen
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
	EventManager.drain_effects_on_event_close(_current_party, _node_state_for_effects())
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

## Title → body → optional choices (same animation path for root and nested segments).
## Any of title/body/choice may be null. Skipping snaps `_segment_skip_nodes`.
## When used with choices, buttons stay input-locked until the sequence finishes or is skipped.
func _animate_segment_title_body_choices(title_node: EventTitle, body_node: EventBody, choice_node: EventChoiceContainer) -> void:
	if not title_node and not body_node and not choice_node:
		return
	_segment_animating = true
	_segment_skip_nodes.clear()
	if title_node:
		_segment_skip_nodes.append(title_node)
	if body_node:
		_segment_skip_nodes.append(body_node)
	if choice_node:
		_segment_skip_nodes.append(choice_node)

	if title_node:
		title_node.duration = anim_title_duration
	if body_node:
		body_node.typewriter_chars_per_second = anim_body_typewriter_chars_per_second
	if choice_node:
		choice_node.choice_stagger = anim_choice_stagger
		choice_node.choice_fade_duration = anim_choice_fade_duration
		choice_node.set_anim_locked(true)

	if title_node:
		await title_node.animate_in()

	if _segment_animating and body_node and is_instance_valid(body_node):
		await body_node.animate_in()

	if _segment_animating and choice_node and is_instance_valid(choice_node):
		await choice_node.animate_in()

	_finish_segment_animation()

func _finish_segment_animation() -> void:
	_segment_animating = false
	_segment_skip_nodes.clear()
	if _active_choice_container:
		_active_choice_container.set_anim_locked(false)

func _skip_segment_animation() -> void:
	if not _segment_animating:
		return
	for node in _segment_skip_nodes:
		if is_instance_valid(node):
			node.snap_visible()
	_finish_segment_animation()

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
