extends Control
class_name TurnOrderPanel

## Lists upcoming turns in a [VBoxContainer] (no scroll). Pins [member CombatController.current_turn_combatant] as the top row until their turn ends.

signal combatant_hover_highlighted(combatant: CombatantData)
signal combatant_hover_unhighlighted()

@export_group("Layout")
## Total rows shown (pinned current + future preview).
@export var preview_entry_count: int = 16

@export_group("Tail fade")
## Last N rows (bottom) use linearly decreasing alpha.
@export var tail_fade_count: int = 3
@export_range(0.0, 1.0) var tail_fade_alpha_top: float = 0.9
@export_range(0.0, 1.0) var tail_fade_alpha_bottom: float = 0.52

@onready var turn_order_display: VBoxContainer = $TurnOrderDisplay
var turn_order_entry_scene: PackedScene = preload("res://scenes/combat/TurnOrderEntry.tscn")


func refresh_turn_order() -> void:
	if not CombatController.combat_timeline or not turn_order_display:
		return
	for child in turn_order_display.get_children():
		child.queue_free()
	var timeline = CombatController.combat_timeline
	var pin: CombatantData = null
	if CombatController.combat_active and CombatController.current_turn_combatant != null:
		var active: CombatantData = CombatController.current_turn_combatant
		if is_instance_valid(active) and not active.is_dead:
			pin = active
	var future_count: int = preview_entry_count - (1 if pin != null else 0)
	future_count = maxi(future_count, 0)
	var preview: Array = timeline.get_turn_preview(maxi(future_count + 8, 16))

	var built: Array[Control] = []
	if pin != null:
		var cast_ui: Dictionary = _active_cast_line(pin)
		var entry_pin: Control = turn_order_entry_scene.instantiate()
		built.append(entry_pin)
		turn_order_display.add_child(entry_pin)
		entry_pin.update_display(pin.display_name, true, str(cast_ui.get("action", "")), int(cast_ui.get("countdown", 0)))
		entry_pin.set_combatant_and_panel(pin, self)

	for j in range(mini(future_count, preview.size())):
		var turn_event: Variant = preview[j]
		if turn_event == null:
			break
		var combatant: CombatantData = turn_event.combatant
		var action_text: String = _get_planned_action_for_turn(preview, j, combatant)
		var cast_countdown: int = _get_cast_countdown(preview, j, combatant)
		var entry: Control = turn_order_entry_scene.instantiate()
		built.append(entry)
		turn_order_display.add_child(entry)
		entry.update_display(turn_event.get_display_name(), false, action_text, cast_countdown)
		entry.set_combatant_and_panel(combatant, self)

	var n: int = built.size()
	for i in range(n):
		_apply_row_fade(built[i], i, n)


func _apply_row_fade(entry: Control, visual_index: int, total_rows: int) -> void:
	if total_rows <= 0 or tail_fade_count <= 0 or visual_index < total_rows - tail_fade_count:
		entry.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var span: int = maxi(tail_fade_count - 1, 1)
	var rel: int = visual_index - (total_rows - tail_fade_count)
	var t: float = clampf(float(rel) / float(span), 0.0, 1.0)
	var a: float = lerpf(tail_fade_alpha_top, tail_fade_alpha_bottom, t)
	entry.modulate = Color(1.0, 1.0, 1.0, a)


func _active_cast_line(combatant: CombatantData) -> Dictionary:
	var timeline = CombatController.combat_timeline
	if timeline == null or combatant == null:
		return {"action": "", "countdown": 0}
	var cast = timeline.get_active_cast(combatant)
	if cast == null or cast.ability == null:
		return {"action": "", "countdown": 0}
	return {"action": cast.ability.ability_name, "countdown": cast.remaining_cast_time}


func _get_planned_action_for_turn(preview: Array, turn_index: int, combatant: CombatantData) -> String:
	var timeline = CombatController.combat_timeline
	if not timeline:
		return ""
	var cast = timeline.get_active_cast(combatant)
	if not cast or not cast.ability:
		return ""
	var ticks_before_this_turn := 0
	for k in range(turn_index):
		if preview[k].combatant == combatant:
			ticks_before_this_turn += 1
	var remaining: int = cast.remaining_cast_time - ticks_before_this_turn
	if remaining <= 0:
		return ""
	return cast.ability.ability_name


func _get_cast_countdown(preview: Array, turn_index: int, combatant: CombatantData) -> int:
	var timeline = CombatController.combat_timeline
	if not timeline:
		return 0
	var cast = timeline.get_active_cast(combatant)
	if not cast:
		return 0
	var ticks_before := 0
	for k in range(turn_index):
		if preview[k].combatant == combatant:
			ticks_before += 1
	return maxi(0, cast.remaining_cast_time - ticks_before)


func highlight_entries_for_combatant(combatant: CombatantData) -> void:
	if not turn_order_display:
		return
	for child in turn_order_display.get_children():
		if child.has_method("set_highlight") and child.get("combatant") == combatant:
			child.set_highlight(true)
	combatant_hover_highlighted.emit(combatant)


func unhighlight_all_entries() -> void:
	if not turn_order_display:
		return
	for child in turn_order_display.get_children():
		if child.has_method("set_highlight"):
			child.set_highlight(false)
	combatant_hover_unhighlighted.emit()
