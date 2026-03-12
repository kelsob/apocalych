extends Control
class_name TurnOrderPanel

## TurnOrderPanel - Owns the turn order list and refreshes it from the combat timeline.
## Handles hover highlight: when an entry is hovered, all entries for that character highlight.

signal combatant_hover_highlighted(combatant: CombatantData)
signal combatant_hover_unhighlighted()

@onready var turn_order_display: HBoxContainer = $NinePatchRect/MarginContainer/ScrollContainer/TurnOrderDisplay
var turn_order_entry_scene: PackedScene = preload("res://scenes/combat/TurnOrderEntry.tscn")

func refresh_turn_order() -> void:
	if not CombatController.combat_timeline:
		return
	if not turn_order_display:
		return
	for child in turn_order_display.get_children():
		child.queue_free()
	var preview = CombatController.combat_timeline.get_turn_preview(25)
	for i in range(preview.size()):
		var turn_event = preview[i]
		var action_text := _get_planned_action_for_turn(preview, i, turn_event.combatant)
		var cast_countdown := _get_cast_countdown(preview, i, turn_event.combatant)
		var entry = turn_order_entry_scene.instantiate()
		turn_order_display.add_child(entry)
		entry.update_display(turn_event.get_display_name(), i == 0, action_text, cast_countdown)
		entry.set_combatant_and_panel(turn_event.combatant, self)

## For a given turn index in the preview, get the "planned" action text for that combatant.
## Empty if they have no active cast, or "AbilityName - N turns" if channeled/delayed and still active.
func _get_planned_action_for_turn(preview: Array, turn_index: int, combatant: CombatantData) -> String:
	var timeline = CombatController.combat_timeline
	if not timeline:
		return ""
	var cast = timeline.get_active_cast(combatant)
	if not cast or not cast.ability:
		return ""
	# How many of this combatant's turns have already happened before this one in the preview?
	var ticks_before_this_turn := 0
	for j in range(turn_index):
		if preview[j].combatant == combatant:
			ticks_before_this_turn += 1
	var remaining: int = cast.remaining_cast_time - ticks_before_this_turn
	if remaining <= 0:
		return ""
	var turn_str := "turn" if remaining == 1 else "turns"
	return "%s - %d %s" % [cast.ability.ability_name, remaining, turn_str]

## Returns the remaining cast ticks for a combatant at a given preview index, or 0 if no active cast.
func _get_cast_countdown(preview: Array, turn_index: int, combatant: CombatantData) -> int:
	var timeline = CombatController.combat_timeline
	if not timeline:
		return 0
	var cast = timeline.get_active_cast(combatant)
	if not cast:
		return 0
	var ticks_before := 0
	for j in range(turn_index):
		if preview[j].combatant == combatant:
			ticks_before += 1
	return max(0, cast.remaining_cast_time - ticks_before)

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
