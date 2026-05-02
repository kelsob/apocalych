extends Resource
class_name Weapon

## Weapon - Stat stick for characters. [member tier] is a **numeric index** (0 = lowest … [enum Tier.MITHRIL] = highest).
## Display: [member tier_prefixes] supplies the **prefix string per tier** when set; otherwise global [member TIER_NAMES] (metal names) is used.
## Affects damage in combat. Slots unlock by tier; enchantments add bonuses.
## Loadout: heroes use [member HeroCharacter.weapon_slot_a] / [member weapon_slot_b]; two-handers and
## dual-wield bundles set [member occupies_both_slots] so slot B is cleared in [method HeroCharacter.apply_loadout_constraints].

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

## How many discrete upgrade tiers exist (matches [enum Tier] count).
static func tier_count() -> int:
	return Tier.MITHRIL + 1

const DEFAULT_BASIC_ATTACK_PATH: String = "res://resources/abilities/shared/basic_attack.tres"

## Player-facing item name for inventory / tooltips (e.g. [code]Simple sword[/code]). Empty = [code]"{tier flavor} {type}"[/code] via [method get_item_display_name].
@export var display_name: String = ""
## Tag for [method HeroCharacter.hero_has_weapon_type] and [member Ability.required_weapon_type_ids]. Use the canonical ids from [code]COMBAT_DESIGN.md[/code] section 16.0. Empty = generic (does not satisfy a specific type requirement).
@export var weapon_type_id: String = ""
## When true, this item occupies both hero weapon slots (two-hander or dual-wield bundle). Slot B is unused while equipped in slot A.
@export var occupies_both_slots: bool = false
## Basic attack [Ability] resources granted while this weapon is equipped (combat UI / controller consume in a later step).
@export var granted_basic_attacks: Array[Ability] = []
## If false, tier damage is omitted (shields, focus orbs): only enchantment [code]damage_bonus[/code] counts toward ATK.
@export var contributes_attack_bonus: bool = true
## Optional per-tier label for UI (index [code]0[/code] = lowest tier …). When empty at an index, [member TIER_NAMES] is used for that tier.
@export var tier_prefixes: Array[String] = []
## Inventory / character sheet icon. When null, UI may fall back to [member weapon_type_id] art.
@export var ui_icon: Texture2D

@export var tier: int = Tier.COPPER
## Flat bonus to [member HeroCharacter.get_initiative] while equipped (timeline turn frequency).
@export var initiative_bonus: int = 0
@export var enchantments: Array[WeaponEnchantment] = []


## Number of enchantment slots for this tier
func get_slot_count() -> int:
	var config = TIER_CONFIG.get(tier, TIER_CONFIG[Tier.COPPER])
	return config.get("slots", 1)


## ATK value from tier only (1 for copper, +1 per upgrade). Used for display.
func get_atk() -> int:
	if not contributes_attack_bonus:
		return 0
	var config = TIER_CONFIG.get(tier, TIER_CONFIG[Tier.COPPER])
	return config.get("base_damage", 1)


## Total damage bonus: base from tier + sum of enchantments (tier omitted when [member contributes_attack_bonus] is false).
func get_damage_bonus() -> int:
	var from_enc: int = 0
	for enc in enchantments:
		if enc:
			from_enc += enc.damage_bonus
	if not contributes_attack_bonus:
		return from_enc
	var config = TIER_CONFIG.get(tier, TIER_CONFIG[Tier.COPPER])
	return int(config.get("base_damage", 0)) + from_enc


## Whether all slots are filled
func has_empty_slots() -> bool:
	return enchantments.size() < get_slot_count()


## Copper / Iron / … quality ladder only. Ignores [member tier_prefixes] (use for tooltip tier column vs. proper [member display_name]).
func get_metal_tier_name() -> String:
	var idx: int = clampi(int(tier), 0, Tier.MITHRIL)
	if idx >= 0 and idx < TIER_NAMES.size():
		return TIER_NAMES[idx]
	return "Unknown"


## Human-readable type for UI from [member weapon_type_id] (e.g. [code]sword[/code] → [code]Sword[/code]).
func get_weapon_type_display_name() -> String:
	if weapon_type_id.is_empty():
		return "Weapon"
	var parts: PackedStringArray = weapon_type_id.split("_")
	for i in parts.size():
		if parts[i].length() > 0:
			parts[i] = parts[i].capitalize()
	return " ".join(parts)


## Title line when [member display_name] is empty: [code]"{tier flavor} {type}"[/code] using [method get_tier_name] and [method get_weapon_type_display_name].
func get_item_display_name() -> String:
	var custom: String = display_name.strip_edges()
	if not custom.is_empty():
		return custom
	return "%s %s" % [get_tier_name(), get_weapon_type_display_name()]


## Display prefix for the current [member tier] (weapon-specific when [member tier_prefixes] is set).
func get_tier_name() -> String:
	var idx: int = clampi(int(tier), 0, Tier.MITHRIL)
	if idx < tier_prefixes.size():
		var flavor: String = str(tier_prefixes[idx]).strip_edges()
		if not flavor.is_empty():
			return flavor
	if idx >= 0 and idx < TIER_NAMES.size():
		return TIER_NAMES[idx]
	return "Unknown"


## 1-based tier for UI (e.g. "3 / 5").
func get_tier_rank_one_based() -> int:
	return clampi(int(tier), 0, Tier.MITHRIL) + 1


static func tier_rank_max() -> int:
	return tier_count()


## Create a default copper weapon (1 slot, +1 damage)
static func create_default() -> Weapon:
	var w := Weapon.new()
	w.tier = Tier.COPPER
	w.enchantments = []
	w.weapon_type_id = ""
	w.occupies_both_slots = false
	w.contributes_attack_bonus = true
	w.granted_basic_attacks = []
	if ResourceLoader.exists(DEFAULT_BASIC_ATTACK_PATH):
		var ab = load(DEFAULT_BASIC_ATTACK_PATH)
		if ab is Ability:
			w.granted_basic_attacks = [ab as Ability]
	return w
