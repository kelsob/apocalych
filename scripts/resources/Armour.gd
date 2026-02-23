extends Resource
class_name Armour

## Armour - Single armour slot for characters. Tiered (copper→mithril), same upgrade path as weapons.
## Affects damage taken in combat via defense bonus.

enum Tier {
	COPPER,
	IRON,
	DIAMOND,
	PLATINUM,
	MITHRIL
}

## Tier config: defense_bonus (reduces incoming damage or adds to effective armor)
const TIER_CONFIG: Dictionary = {
	Tier.COPPER: {"defense_bonus": 0},
	Tier.IRON: {"defense_bonus": 1},
	Tier.DIAMOND: {"defense_bonus": 2},
	Tier.PLATINUM: {"defense_bonus": 3},
	Tier.MITHRIL: {"defense_bonus": 4}
}

const TIER_NAMES: Array[String] = ["Copper", "Iron", "Diamond", "Platinum", "Mithril"]

@export var tier: int = Tier.COPPER


## DEF value from tier (0 for copper, +1 per upgrade). Same as get_defense_bonus(); use for display or combat.
func get_def() -> int:
	var config = TIER_CONFIG.get(tier, TIER_CONFIG[Tier.COPPER])
	return config.get("defense_bonus", 0)


## Defense bonus from this tier (reduces incoming damage in combat)
func get_defense_bonus() -> int:
	return get_def()


## Tier display name
func get_tier_name() -> String:
	if tier >= 0 and tier < TIER_NAMES.size():
		return TIER_NAMES[tier]
	return "Unknown"


## Create a default copper armour
static func create_default() -> Armour:
	var a := Armour.new()
	a.tier = Tier.COPPER
	return a
