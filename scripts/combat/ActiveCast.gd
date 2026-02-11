extends RefCounted
class_name ActiveCast

## ActiveCast - Tracks an ability being cast over multiple turns
## Handles delayed casts, channeled abilities, and interruption

var caster: CombatantData = null
var ability: Ability = null
var targets: Array = []  # Array of CombatantData
var base_cast_time: int = 0
var remaining_cast_time: int = 0
var can_be_interrupted: bool = true
var is_channeled: bool = false

func _init(p_caster: CombatantData, p_ability: Ability, p_targets: Array):
	caster = p_caster
	ability = p_ability
	targets = p_targets
	base_cast_time = p_ability.get_modified_cast_time()
	remaining_cast_time = base_cast_time
	can_be_interrupted = p_ability.can_be_interrupted
	is_channeled = (p_ability.ability_type == Ability.AbilityType.CHANNELED)

## Process a turn tick for this cast
## Returns true if cast is complete and should resolve
func tick() -> bool:
	remaining_cast_time -= 1
	
	# Channeled abilities apply effects each tick
	if is_channeled and remaining_cast_time > 0:
		# Effects will be applied by CombatController
		pass
	
	return remaining_cast_time <= 0

## Check if this cast can be interrupted
func can_interrupt() -> bool:
	if not can_be_interrupted:
		return false
	
	# Check if caster has uninterruptible status
	if caster and caster.combatant_stats:
		return not caster.combatant_stats.is_uninterruptible()
	
	return true

## Get progress as a percentage (for UI)
func get_progress() -> float:
	if base_cast_time == 0:
		return 1.0
	return 1.0 - (float(remaining_cast_time) / float(base_cast_time))
