extends Resource
class_name Ability

## Ability - Defines a combat ability with costs, cast time, targeting, and effects
## Abilities are data-driven resources that can be modified by items/passives

enum AbilityType {
	INSTANT,      # Resolves immediately
	DELAYED_CAST, # Resolves after X turns, does nothing until then
	CHANNELED     # Applies effects each turn, can be interrupted
}

enum TargetingType {
	SELF,
	SINGLE_ALLY,
	SINGLE_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	ALL_COMBATANTS,
	RANDOM_ENEMY,
	RANDOM_ALLY
}

@export var ability_name: String = ""
@export var ability_id: String = ""
@export var description: String = ""

# Costs & Timing
@export var ap_cost: int = 1
@export var base_cast_time: int = 0  # Turns to resolve (0 = instant)
@export var ability_type: AbilityType = AbilityType.INSTANT

# Targeting
@export var targeting_type: TargetingType = TargetingType.SINGLE_ENEMY
@export var requires_target: bool = true

# Effects
@export var effects: Array[AbilityEffect] = []

# Interruption
@export var can_be_interrupted: bool = true

# Modifiers (applied by items/passives at runtime)
# These are dictionaries that modify ability properties
# e.g., {"cast_time": -1, "ap_cost": -1, "potency_multiplier": 1.2}
var runtime_modifiers: Dictionary = {}

## Get the modified cast time based on runtime modifiers
func get_modified_cast_time() -> int:
	var modified_time = base_cast_time
	if runtime_modifiers.has("cast_time"):
		modified_time += runtime_modifiers.cast_time
	return max(0, modified_time)  # Can't be negative

## Get the modified AP cost based on runtime modifiers
func get_modified_ap_cost() -> int:
	var modified_cost = ap_cost
	if runtime_modifiers.has("ap_cost"):
		modified_cost += runtime_modifiers.ap_cost
	return max(0, modified_cost)  # Can't be negative

## Apply runtime modifier from equipment/passive
func apply_modifier(modifier_dict: Dictionary):
	for key in modifier_dict:
		if runtime_modifiers.has(key):
			runtime_modifiers[key] += modifier_dict[key]
		else:
			runtime_modifiers[key] = modifier_dict[key]

## Clear all runtime modifiers (e.g., when equipment changes)
func clear_modifiers():
	runtime_modifiers.clear()

## Check if this ability can target the specified target
func can_target(caster_is_player: bool, target_is_player: bool) -> bool:
	match targeting_type:
		TargetingType.SELF:
			return false  # Self-targeting doesn't need validation
		TargetingType.SINGLE_ALLY:
			return caster_is_player == target_is_player
		TargetingType.SINGLE_ENEMY:
			return caster_is_player != target_is_player
		TargetingType.RANDOM_ALLY:
			return caster_is_player == target_is_player
		TargetingType.RANDOM_ENEMY:
			return caster_is_player != target_is_player
		_:
			return true  # AoE abilities don't need target validation
