extends Resource
class_name Enemy

## Enemy - Defines an enemy type with stats, abilities, and rewards
## Enemies are data-driven and configured in the editor

@export var enemy_name: String = ""
@export var enemy_id: String = ""
@export var description: String = ""

# Base stats
@export var max_health: int = 10
@export var base_stats: Dictionary = {
	"strength": 10,
	"dexterity": 10,
	"constitution": 10,
	"intelligence": 10,
	"wisdom": 10,
	"charisma": 10
}

# Abilities this enemy can use
@export var abilities: Array[Ability] = []

# AI behavior (simple for now - can be expanded later)
@export_enum("Aggressive", "Defensive", "Balanced", "Support") var ai_behavior: String = "Balanced"

# Rewards
@export var xp_reward: int = 10
@export var gold_reward: int = 0
@export var loot_table: Dictionary = {}  # item_id: drop_chance (0.0-1.0)

## Initialize combat stats from this enemy definition
func create_combat_stats() -> CombatantStats:
	var stats = CombatantStats.new()
	stats.max_health = max_health
	stats.current_health = max_health
	stats.core_stats = base_stats.duplicate()
	
	# Calculate derived stats
	stats.base_speed = stats._calculate_speed_from_dex(base_stats.dexterity)
	stats.base_ap_per_turn = stats._calculate_ap_per_turn_from_con(base_stats.constitution)
	stats.current_ap = min(3, stats.max_ap)
	
	return stats
