extends Resource
class_name Weapon

## Weapon - Stat stick for characters. Tiered (copper→mithril) with enchantment slots.
## Affects damage in combat. Slots unlock by tier; enchantments add bonuses.

enum Tier {
	COPPER,
	IRON,
	DIAMOND,
	PLATINUM,
	MITHRIL
}

## Tier config: base_damage, slot_count
const TIER_CONFIG: Dictionary = {
	Tier.COPPER: {"base_damage": 1, "slots": 1},
	Tier.IRON: {"base_damage": 2, "slots": 1},
	Tier.DIAMOND: {"base_damage": 3, "slots": 2},
	Tier.PLATINUM: {"base_damage": 4, "slots": 2},
	Tier.MITHRIL: {"base_damage": 5, "slots": 3}
}

const TIER_NAMES: Array[String] = ["Copper", "Iron", "Diamond", "Platinum", "Mithril"]

@export var tier: int = Tier.COPPER
@export var enchantments: Array[WeaponEnchantment] = []


## Number of enchantment slots for this tier
func get_slot_count() -> int:
	var config = TIER_CONFIG.get(tier, TIER_CONFIG[Tier.COPPER])
	return config.get("slots", 1)


## Total damage bonus: base from tier + sum of enchantments
func get_damage_bonus() -> int:
	var config = TIER_CONFIG.get(tier, TIER_CONFIG[Tier.COPPER])
	var total: int = config.get("base_damage", 0)
	for enc in enchantments:
		if enc:
			total += enc.damage_bonus
	return total


## Whether all slots are filled
func has_empty_slots() -> bool:
	return enchantments.size() < get_slot_count()


## Tier display name
func get_tier_name() -> String:
	if tier >= 0 and tier < TIER_NAMES.size():
		return TIER_NAMES[tier]
	return "Unknown"


## Create a default copper weapon (1 slot, +1 damage)
static func create_default() -> Weapon:
	var w := Weapon.new()
	w.tier = Tier.COPPER
	w.enchantments = []
	return w
