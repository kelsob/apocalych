extends Resource
class_name HeroCharacter

## Runtime hero for a run: display name, race, class, progression, gear, and traits.
## Party selection and recruitment build **instances** (often from shared templates later).
## Primary attributes: strength, agility, constitution, intellect, spirit, charisma, luck — from class [member Class.stat_spread] plus optional race [member Race.stat_adjustments] (not clamped; race can push values above or below a typical band).
## Combat uses derived atk / def / spd (initiative), mag / mag_def (see get_combat_core_stats). Initiative also comes from agility + spirit + gear/race bonuses ([method get_initiative]).

# Character identity
## Stable id for meta unlocks, saves, recruitment, and tags (`hero:<id>` in TagManager when set).
@export var hero_id: String = ""
@export var member_name: String = ""
@export var race: Race = null
@export var class_resource: Class = null

## Which portrait model this character uses (1 or 2). Set once on initialize(), never changes.
var portrait_model: int = 1

# Character progression
@export var level: int = 1
@export var experience: int = 0
@export var experience_to_next_level: int = 100

# Character health
@export var max_health: int = 10
@export var current_health: int = 10

# Character inventory: item_id -> count
var inventory: Dictionary = {}

# Intrinsic traits this character carries (trait IDs). Cannot be traded or removed normally.
var traits: Array[String] = []

## Primary weapon slot (bow, sword, two-hander, etc.).
@export var weapon_slot_a: Weapon = null
## Secondary slot (shield, off-hand dagger pair, etc.). Cleared when slot A's weapon has [member Weapon.occupies_both_slots].
@export var weapon_slot_b: Weapon = null

## If non-empty, only weapons whose [member Weapon.weapon_type_id] appears here may occupy slot A. Empty = no type restriction.
@export var allowed_weapon_type_ids_slot_a: Array[String] = []
## Same for slot B (off-hand / second weapon).
@export var allowed_weapon_type_ids_slot_b: Array[String] = []
## If false, slot B is cleared and cannot hold a weapon (e.g. two-handed-only hero in data). Ignored when slot A [member Weapon.occupies_both_slots] already clears B.
@export var allows_weapon_slot_b: bool = true

var armour: Armour = null

## Combat formation: front line blocks melee reach to the back row on the same side (unless stealthed / ranged).
## Used when [member use_class_default_formation] is false (player override).
@export_enum("Front", "Back") var combat_formation_row: int = 0
## If true, combat uses [member Class.default_combat_formation_row] from [member class_resource]. If false, uses [member combat_formation_row].
@export var use_class_default_formation: bool = true


func resolve_initial_formation_row() -> int:
	var who: String = member_name if not member_name.is_empty() else "<unnamed_hero>"
	if use_class_default_formation:
		assert(class_resource != null, "combat positioning: hero '%s' has use_class_default_formation=true but class_resource is null" % who)
		var class_row: int = class_resource.default_combat_formation_row
		var class_label: String = class_resource.name if not class_resource.name.is_empty() else str(class_resource.resource_path)
		assert(class_row == 0 or class_row == 1, "combat positioning: hero '%s' class '%s' default_combat_formation_row must be 0 (Front) or 1 (Back), got %d" % [who, class_label, class_row])
		print("combat positioning: resolve row hero='%s' mode=class_default class='%s' default_combat_formation_row=%d (%s)" % [who, class_label, class_row, "Front" if class_row == 0 else "Back"])
		return class_row
	var hero_row: int = combat_formation_row
	assert(hero_row == 0 or hero_row == 1, "combat positioning: hero '%s' combat_formation_row must be 0 or 1, got %d" % [who, hero_row])
	print("combat positioning: resolve row hero='%s' mode=hero_override combat_formation_row=%d (%s)" % [who, hero_row, "Front" if hero_row == 0 else "Back"])
	return hero_row


## After [method Resource.duplicate] from a template, give this run instance its own [Weapon] copies so tier/enchant changes never mutate the shared `.tres` or another hero's gear.
func duplicate_equipped_weapons_for_run() -> void:
	var a0: Weapon = weapon_slot_a
	var b0: Weapon = weapon_slot_b
	if a0 != null:
		weapon_slot_a = a0.duplicate(true)
	if b0 != null:
		weapon_slot_b = b0.duplicate(true) if b0 != a0 else weapon_slot_a


## If slot A's weapon uses both hands, clear slot B (see [member Weapon.occupies_both_slots]). Also clears B when [member allows_weapon_slot_b] is false.
func apply_loadout_constraints() -> void:
	var a: Weapon = weapon_slot_a
	if a != null and a.occupies_both_slots:
		weapon_slot_b = null
	if not allows_weapon_slot_b:
		weapon_slot_b = null


func get_weapon_slot_a() -> Weapon:
	return weapon_slot_a


func get_weapon_slot_b() -> Weapon:
	if weapon_slot_a != null and weapon_slot_a.occupies_both_slots:
		return null
	return weapon_slot_b


## All equipped weapons for damage, tags, and ability checks (slot B omitted when A occupies both slots).
func get_all_equipped_weapons() -> Array[Weapon]:
	var out: Array[Weapon] = []
	var a: Weapon = get_weapon_slot_a()
	if a:
		out.append(a)
	var b: Weapon = get_weapon_slot_b()
	if b:
		out.append(b)
	return out


## Sum of [method Weapon.get_damage_bonus] across equipped weapons.
func get_total_weapon_damage_bonus() -> int:
	var total: int = 0
	for w in get_all_equipped_weapons():
		if w:
			total += w.get_damage_bonus()
	return total


## True if any equipped weapon's [member Weapon.weapon_type_id] matches (non-empty [param type_id] only).
func hero_has_weapon_type(type_id: String) -> bool:
	if type_id.is_empty():
		return true
	for w in get_all_equipped_weapons():
		if w and w.weapon_type_id == type_id:
			return true
	return false


## [param ability] is usable given current gear when every entry in [member Ability.required_weapon_type_ids] is satisfied by some equipped weapon.
func ability_allowed_by_equipment(ability: Ability) -> bool:
	if ability == null:
		return true
	if ability.required_weapon_type_ids.is_empty():
		return true
	for tid in ability.required_weapon_type_ids:
		if str(tid).is_empty():
			continue
		if not hero_has_weapon_type(str(tid)):
			return false
	return true


## [param slot_index] 0 = A, 1 = B. Empty allow-list = any [member Weapon.weapon_type_id] allowed.
func is_weapon_allowed_for_slot(w: Weapon, slot_index: int) -> bool:
	if w == null:
		return true
	if slot_index == 1 and not allows_weapon_slot_b:
		return false
	var allowed: Array = allowed_weapon_type_ids_slot_a if slot_index == 0 else allowed_weapon_type_ids_slot_b
	if allowed.is_empty():
		return true
	if w.weapon_type_id.is_empty():
		return false
	return w.weapon_type_id in allowed


## Clears slots whose weapon type is not allowed. Call after [method apply_loadout_constraints] or as part of loadout maintenance.
func sanitize_weapon_slots_to_allow_lists() -> void:
	var a: Weapon = weapon_slot_a
	if a != null and not is_weapon_allowed_for_slot(a, 0):
		weapon_slot_a = null
	var b: Weapon = weapon_slot_b
	if b != null and not is_weapon_allowed_for_slot(b, 1):
		weapon_slot_b = null


## Ensure slot A has a default copper weapon when empty.
func ensure_default_weapon_slot_a() -> void:
	apply_loadout_constraints()
	sanitize_weapon_slots_to_allow_lists()
	apply_loadout_constraints()
	if weapon_slot_a == null:
		weapon_slot_a = Weapon.create_default()
	apply_loadout_constraints()

## Add items to this character's inventory. Returns true if added.
func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	if not ItemDatabase.has_item(item_id):
		push_warning("HeroCharacter.add_item: Unknown item_id '%s'" % item_id)
		return false
	var item := ItemDatabase.get_item(item_id)
	var current: int = int(inventory.get(item_id, 0))
	var can_add := mini(count, item.stack_size - current) if item.stack_size < 99 else count
	if can_add <= 0:
		return false
	inventory[item_id] = current + can_add
	return true

## Remove items from this character's inventory. Returns true if removed.
func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var current: int = int(inventory.get(item_id, 0))
	if current <= 0:
		return false
	var to_remove := mini(count, current)
	inventory[item_id] = current - to_remove
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true

func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func has_item(item_id: String) -> bool:
	return inventory.get(item_id, 0) > 0

## Add a trait to this character. No-ops silently if they already have it.
func add_trait(trait_id: String) -> bool:
	if trait_id.is_empty():
		return false
	if not TraitDatabase.has_trait(trait_id):
		push_warning("HeroCharacter.add_trait: Unknown trait_id '%s'" % trait_id)
		return false
	if trait_id in traits:
		return false
	traits.append(trait_id)
	return true

func has_trait(trait_id: String) -> bool:
	return trait_id in traits

func get_trait_ids() -> Array[String]:
	return traits.duplicate()

func get_inventory_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in inventory.keys():
		if inventory[k] > 0:
			ids.append(str(k))
	return ids

## Initialize after identity (race/class/name) is set — fresh run state for this instance.
func initialize():
	portrait_model = randi() % 2 + 1  # 1 or 2 — fixed for this character's lifetime
	level = 1
	experience = 0
	experience_to_next_level = 100
	apply_loadout_constraints()
	sanitize_weapon_slots_to_allow_lists()
	if weapon_slot_a == null:
		weapon_slot_a = Weapon.create_default()
	apply_loadout_constraints()
	if armour == null:
		armour = Armour.create_default()

	# Base HP scales with constitution (CON 5 = +0 from stat; each point above 5 adds +1 max HP at creation)
	var stats := get_final_stats()
	var con: int = int(stats.get("constitution", PRIMARY_STAT_NEUTRAL))
	max_health = 10 + maxi(0, con - PRIMARY_STAT_MIN)
	current_health = max_health

	print("Initialized %s: Level %d, Max HP: %d" % [member_name, level, max_health])

func get_weapon_type() -> String:
	if class_resource and class_resource.weapon_type and not class_resource.weapon_type.is_empty():
		return class_resource.weapon_type
	return "Weapon"

func get_armour_type() -> String:
	if class_resource and class_resource.armour_type and not class_resource.armour_type.is_empty():
		return class_resource.armour_type
	return "Armour"


## Theme colour from [member class_resource] for UI. Matches [member Class.class_color] fallback when missing class.
func get_class_color() -> Color:
	if class_resource != null:
		return class_resource.class_color
	return Color(0.82, 0.84, 0.88, 1.0)


const PRIMARY_STAT_KEYS: Array[String] = [
	"strength",
	"agility",
	"constitution",
	"intellect",
	"spirit",
	"charisma",
	"luck",
]

## Reference low end for derived combat formulas (e.g. defense from CON); primary stats themselves are not clamped.
const PRIMARY_STAT_MIN: int = 5
## Typical midpoint for fallbacks and event checks.
const PRIMARY_STAT_NEUTRAL: int = 8

func _has_full_class_stat_spread(cr: Class) -> bool:
	if cr == null or cr.stat_spread.is_empty():
		return false
	for key in PRIMARY_STAT_KEYS:
		if not cr.stat_spread.has(key):
			return false
	return true


## Final primary attributes: prefer [member Class.stat_spread] + [member Race.stat_adjustments] (not clamped — race can push beyond a typical band); else legacy race base + class modifiers.
func get_final_stats() -> Dictionary:
	var stats: Dictionary = {}

	if class_resource != null and _has_full_class_stat_spread(class_resource):
		for key in PRIMARY_STAT_KEYS:
			stats[key] = int(class_resource.stat_spread.get(key, PRIMARY_STAT_NEUTRAL))
		if race and race.stat_adjustments:
			for key in PRIMARY_STAT_KEYS:
				if race.stat_adjustments.has(key):
					var adj: int = int(race.stat_adjustments[key])
					stats[key] = int(stats[key]) + adj
		return stats

	# Legacy: race base + additive class modifiers, default neutral 10
	if race and race.base_stats:
		stats = race.base_stats.duplicate()

	if class_resource and class_resource.stat_modifiers:
		for stat in class_resource.stat_modifiers:
			stats[stat] = stats.get(stat, PRIMARY_STAT_NEUTRAL) + class_resource.stat_modifiers[stat]

	for key in PRIMARY_STAT_KEYS:
		if not stats.has(key):
			stats[key] = PRIMARY_STAT_NEUTRAL

	return stats


## Damage for player basic attacks: [code]primary_stat × basic_attack_stat_scaling_rate[/code] from class data (resolved in combat; not read from the ability effect).
func get_basic_attack_damage_from_primary_stat() -> float:
	if class_resource == null:
		return 0.0
	var stat_key: String = str(class_resource.basic_attack_primary_stat).strip_edges()
	if stat_key.is_empty() or not stat_key in PRIMARY_STAT_KEYS:
		return 0.0
	var rate: float = float(class_resource.basic_attack_stat_scaling_rate)
	var stats := get_final_stats()
	var raw: float = float(stats.get(stat_key, 0))
	return raw * rate


## Initiative drives turn order in combat: agility + spirit + weapon/armour bonuses + race [member Race.initiative_bonus] + trait hooks ([method get_initiative_bonus_from_traits]).
func get_total_initiative_bonus_from_equipment() -> int:
	var n: int = 0
	for w in get_all_equipped_weapons():
		if w:
			n += w.initiative_bonus
	if armour:
		n += armour.initiative_bonus
	return n


func get_initiative_bonus_from_traits() -> int:
	return 0


## Derived initiative total (minimum 1). Feeds [member CombatantStats.base_speed] for [CombatTimeline].
func get_initiative() -> int:
	var s := get_final_stats()
	var total: int = int(s.get("agility", 0)) + int(s.get("spirit", 0))
	total += get_total_initiative_bonus_from_equipment()
	total += get_initiative_bonus_from_traits()
	if race:
		total += race.initiative_bonus
	return maxi(1, total)


## Map primary stats to combat engine stats (atk, def, spd, mag, mag_def). [code]spd[/code] holds **initiative** for heroes (same value as [method get_initiative]) so ability [member AbilityEffect.stat_scaling] keys stay compatible.
func get_combat_core_stats() -> Dictionary:
	var s := get_final_stats()
	var str_v: int = int(s.get("strength", PRIMARY_STAT_NEUTRAL))
	var con: int = int(s.get("constitution", PRIMARY_STAT_NEUTRAL))
	var intel: int = int(s.get("intellect", PRIMARY_STAT_NEUTRAL))
	var spr: int = int(s.get("spirit", PRIMARY_STAT_NEUTRAL))
	var init_v: int = get_initiative()
	return {
		"atk": str_v,
		"def": maxi(0, con - PRIMARY_STAT_MIN),
		"spd": init_v,
		"mag": intel,
		"mag_def": spr,
	}

func take_damage(amount: int) -> bool:
	current_health = max(0, current_health - amount)
	return current_health > 0

func heal(amount: int):
	current_health = min(max_health, current_health + amount)

func is_alive() -> bool:
	return current_health > 0

## Get all rest abilities for this character (1 from race, 2 from class)
func get_rest_abilities() -> Array[RestAbility]:
	var result: Array[RestAbility] = []
	if race and race.rest_ability:
		result.append(race.rest_ability)
	if class_resource:
		for ra in class_resource.rest_abilities:
			if ra:
				result.append(ra)
	return result

## Simulate gain_experience(amount) and return the sequence of states for UI animation.
## Does NOT modify any state. Each entry: {level, experience, experience_to_next_level}.
## steps[0] = current state before XP is applied.
## steps[1..n] = state after each level-up, with final resting experience in the last entry.
func simulate_xp_gain(amount: int) -> Array:
	var steps: Array = []
	var sim_level := level
	var sim_xp := experience
	var sim_to_next := experience_to_next_level
	steps.append({"level": sim_level, "experience": sim_xp, "experience_to_next_level": sim_to_next})
	sim_xp += amount
	while sim_xp >= sim_to_next:
		sim_xp -= sim_to_next
		sim_level += 1
		sim_to_next = int(100 * pow(1.5, sim_level - 1))
		steps.append({"level": sim_level, "experience": 0, "experience_to_next_level": sim_to_next})
	steps[steps.size() - 1]["experience"] = sim_xp
	return steps

## Gain experience and level up if threshold reached
func gain_experience(amount: int):
	experience += amount
	while experience >= experience_to_next_level:
		level_up()

## Level up the character
func level_up():
	level += 1
	experience -= experience_to_next_level
	experience_to_next_level = int(100 * pow(1.5, level - 1))

	var stats := get_final_stats()
	var con: int = int(stats.get("constitution", PRIMARY_STAT_NEUTRAL))
	var health_gain: int = 5 + maxi(0, con - PRIMARY_STAT_MIN) / 2
	max_health += health_gain
	current_health = max_health

	print("%s leveled up to level %d! Max HP: %d (+%d)" % [member_name, level, max_health, health_gain])

## Returns the map/event portrait for this character based on their fixed portrait_model.
func get_portrait() -> Texture2D:
	if not race:
		return null
	return race.portrait_1 if portrait_model == 1 else race.portrait_2

## Returns the combat portrait for this character based on their fixed portrait_model.
func get_combat_portrait() -> Texture2D:
	if not race:
		return null
	return race.combat_portrait_1 if portrait_model == 1 else race.combat_portrait_2
