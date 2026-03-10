extends Resource
class_name Enemy

## Enemy - Defines an enemy type with stats, abilities, and rewards
## Enemies are data-driven and configured in the editor

enum Faction {
	WILD,     ## Creatures and Beasts
	FEL,      ## Goblin / Uruk / Undead forces
	HUMAN,
	ELVEN,
	DWARVEN,
	HOBBIT
}

@export var enemy_name: String = ""
@export var enemy_id: String = ""
@export var description: String = ""
@export var enemy_type: String = ""  ## Flavour descriptor e.g. "pack hunter", "stone slime"

# Faction and creature classification
@export var faction: Faction = Faction.WILD
## Bitfield tags. Check tags with: enemy.creature_tags & Enemy.CreatureTag.UNDEAD
@export_flags("Beast", "Humanoid", "Undead", "Spectral", "Demon", "Construct", "Dragon", "Cursed", "Corrupted", "Plant", "Elemental") var creature_tags: int = 0

# Base stats (Dragon Quest style: flat values, no derivation)
@export var max_health: int = 10
@export var atk: int = 5       ## Physical attack power
@export var def: int = 0       ## Physical defense (flat damage reduction)
@export var spd: int = 5       ## Speed — determines turn frequency
@export var mag: int = 0       ## Magical attack power
@export var mag_def: int = 0   ## Magical defense

# Abilities this enemy can use
@export var abilities: Array[Ability] = []

# AI behavior
@export_enum("Aggressive", "Defensive", "Balanced", "Support") var ai_behavior: String = "Balanced"

# Rewards
@export var xp_reward: int = 10
@export var gold_reward: int = 0
@export var loot_table: Dictionary = {}  # item_id: drop_chance (0.0–1.0)

## Build runtime CombatantStats from this enemy definition
func create_combat_stats() -> CombatantStats:
	var stats := CombatantStats.new()
	stats.max_health = max_health
	stats.current_health = max_health
	stats.core_stats = {
		"atk": atk,
		"def": def,
		"spd": spd,
		"mag": mag,
		"mag_def": mag_def
	}
	stats.base_speed = float(spd)
	stats.base_ap_per_turn = 3
	stats.current_ap = 3
	return stats
