extends PanelContainer
class_name TurnOrderPanel

## TurnOrderPanel - Owns the turn order list and refreshes it from the combat timeline.
## Handles hover highlight: when an entry is hovered, all entries for that character highlight.

signal combatant_hover_highlighted(combatant: CombatantData)
signal combatant_hover_unhighlighted()

@onready var turn_order_display: HBoxContainer = $VBoxContainer/ScrollContainer/TurnOrderDisplay
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
		var entry = turn_order_entry_scene.instantiate()
		turn_order_display.add_child(entry)
		entry.update_display(
			turn_event.get_display_name(),
			turn_event.turn_time,
			i == 0
		)
		entry.set_combatant_and_panel(turn_event.combatant, self)

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
