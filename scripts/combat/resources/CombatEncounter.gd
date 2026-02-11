extends Resource
class_name CombatEncounter

## CombatEncounter - Defines a specific combat encounter
## Referenced by EventManager when starting combat

@export var encounter_id: String = ""
@export var encounter_name: String = ""
@export var description: String = ""

# Enemies in this encounter
@export var enemies: Array[Enemy] = []

# Environment effects (applied to all combatants at start)
@export var environment_statuses: Array[StatusEffect] = []

# Victory rewards (override enemy rewards if needed)
@export var bonus_xp: int = 0
@export var bonus_gold: int = 0
@export var guaranteed_loot: Array[String] = []  # item_ids

# Special conditions
@export var can_escape: bool = true
@export var escape_difficulty: int = 0  # Required stat check to escape
@export var time_limit: int = 0  # Turn limit (0 = no limit)
@export var special_victory_condition: String = ""  # Custom victory condition description

## Get total XP reward
func get_total_xp() -> int:
	var total = bonus_xp
	for enemy in enemies:
		total += enemy.xp_reward
	return total

## Get total gold reward
func get_total_gold() -> int:
	var total = bonus_gold
	for enemy in enemies:
		total += enemy.gold_reward
	return total
