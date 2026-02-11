extends RefCounted
class_name TurnEvent

## TurnEvent - Represents a single turn in the combat timeline
## Used for queuing and displaying turn order

var combatant: CombatantData = null
var turn_time: float = 0.0
var turn_number: int = 0

func _init(p_combatant: CombatantData, p_turn_time: float, p_turn_number: int = 0):
	combatant = p_combatant
	turn_time = p_turn_time
	turn_number = p_turn_number

## Get display name for UI
func get_display_name() -> String:
	if combatant:
		return combatant.display_name
	return "Unknown"

## Check if this turn belongs to a player combatant
func is_player_turn() -> bool:
	if combatant:
		return combatant.is_player
	return false
