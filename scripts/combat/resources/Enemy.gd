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
@export var combat_portrait: Texture2D = preload("res://assets/enemies/portraits/bandit-rogue.png")

# Faction and creature classification
@export var faction: Faction = Faction.WILD

## Bit masks for [method get_creature_tag_mask] — keep in sync with [member tag_beast] … [member tag_fel].
const TAG_BEAST: int = 1 << 0
const TAG_HUMANOID: int = 1 << 1
const TAG_UNDEAD: int = 1 << 2
const TAG_SPECTRAL: int = 1 << 3
const TAG_DEMON: int = 1 << 4
const TAG_CONSTRUCT: int = 1 << 5
const TAG_DRAGON: int = 1 << 6
const TAG_CURSED: int = 1 << 7
const TAG_CORRUPTED: int = 1 << 8
const TAG_PLANT: int = 1 << 9
const TAG_ELEMENTAL: int = 1 << 10
const TAG_FLYING: int = 1 << 11
## Fel horrors: goblins, orcs, trolls, etc. (catch-all for [enum Faction.FEL]-aligned threats).
const TAG_FEL: int = 1 << 12

@export_group("Creature tags")
@export var tag_beast: bool = false
@export var tag_humanoid: bool = false
@export var tag_undead: bool = false
@export var tag_spectral: bool = false
@export var tag_demon: bool = false
@export var tag_construct: bool = false
@export var tag_dragon: bool = false
@export var tag_cursed: bool = false
@export var tag_corrupted: bool = false
@export var tag_plant: bool = false
@export var tag_elemental: bool = false
@export var tag_flying: bool = false
@export var tag_fel: bool = false

static var _TAG_NAME_TO_BIT: Dictionary = {
	"beast": TAG_BEAST,
	"humanoid": TAG_HUMANOID,
	"undead": TAG_UNDEAD,
	"spectral": TAG_SPECTRAL,
	"demon": TAG_DEMON,
	"construct": TAG_CONSTRUCT,
	"dragon": TAG_DRAGON,
	"cursed": TAG_CURSED,
	"corrupted": TAG_CORRUPTED,
	"plant": TAG_PLANT,
	"elemental": TAG_ELEMENTAL,
	"flying": TAG_FLYING,
	"fel": TAG_FEL,
}

## Front / back for formation rules (melee must clear front line to reach back on this side).
@export_enum("Front", "Back") var formation_row: int = 0
## AI: tries to use Move toward this row when possible (Indifferent = does not reposition).
@export_enum("Front", "Back", "Indifferent") var preferred_zone: int = 2

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


## Combined bitmask for combat (flying check, [CreatureTagDamageRules], etc.).
func get_creature_tag_mask() -> int:
	var mask := 0
	if tag_beast:
		mask |= TAG_BEAST
	if tag_humanoid:
		mask |= TAG_HUMANOID
	if tag_undead:
		mask |= TAG_UNDEAD
	if tag_spectral:
		mask |= TAG_SPECTRAL
	if tag_demon:
		mask |= TAG_DEMON
	if tag_construct:
		mask |= TAG_CONSTRUCT
	if tag_dragon:
		mask |= TAG_DRAGON
	if tag_cursed:
		mask |= TAG_CURSED
	if tag_corrupted:
		mask |= TAG_CORRUPTED
	if tag_plant:
		mask |= TAG_PLANT
	if tag_elemental:
		mask |= TAG_ELEMENTAL
	if tag_flying:
		mask |= TAG_FLYING
	if tag_fel:
		mask |= TAG_FEL
	return mask


func has_creature_tag(tag_name: String) -> bool:
	var bit: int = int(_TAG_NAME_TO_BIT.get(tag_name.strip_edges().to_lower(), 0))
	if bit == 0:
		return false
	return (get_creature_tag_mask() & bit) != 0


## Debug / logs: e.g. "beast, corrupted, fel"
static func describe_tag_mask(mask: int) -> String:
	var keys: Array = _TAG_NAME_TO_BIT.keys()
	keys.sort()
	var parts: Array[String] = []
	for name in keys:
		var b: int = int(_TAG_NAME_TO_BIT[name])
		if (mask & b) != 0:
			parts.append(str(name))
	return ", ".join(parts)
