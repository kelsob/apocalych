extends Resource
class_name PartyMember

## Party Member - represents a single party member with race, class, and name.
## Primary attributes: strength, agility, constitution, intellect, spirit, charisma, luck.
## Combat still uses derived atk / def / spd / mag / mag_def (see get_combat_core_stats).

# Character identity
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

# Equipped weapon and armour
var weapon: Weapon = null
var armour: Armour = null

## Add items to this character's inventory. Returns true if added.
func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	if not ItemDatabase.has_item(item_id):
		push_warning("PartyMember.add_item: Unknown item_id '%s'" % item_id)
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
		push_warning("PartyMember.add_trait: Unknown trait_id '%s'" % trait_id)
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

## Initialize a new party member after setting race and class.
func initialize():
	portrait_model = randi() % 2 + 1  # 1 or 2 — fixed for this character's lifetime
	level = 1
	experience = 0
	experience_to_next_level = 100
	if weapon == null:
		weapon = Weapon.create_default()
	if armour == null:
		armour = Armour.create_default()

	# Base HP scales with constitution (10 CON = +0 bonus HP from stat)
	var stats := get_final_stats()
	var con: int = int(stats.get("constitution", 10))
	max_health = 10 + maxi(0, con - 10)
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

const PRIMARY_STAT_KEYS: Array[String] = [
	"strength",
	"agility",
	"constitution",
	"intellect",
	"spirit",
	"charisma",
	"luck",
]

## Final primary attributes (race base + class modifiers). Keys: PRIMARY_STAT_KEYS.
func get_final_stats() -> Dictionary:
	var stats: Dictionary = {}

	if race and race.base_stats:
		stats = race.base_stats.duplicate()

	if class_resource and class_resource.stat_modifiers:
		for stat in class_resource.stat_modifiers:
			stats[stat] = stats.get(stat, 10) + class_resource.stat_modifiers[stat]

	for key in PRIMARY_STAT_KEYS:
		if not stats.has(key):
			stats[key] = 10

	return stats


## Map primary stats to combat engine stats (atk, def, spd, mag, mag_def).
func get_combat_core_stats() -> Dictionary:
	var s := get_final_stats()
	var str_v: int = int(s.get("strength", 10))
	var agi: int = int(s.get("agility", 10))
	var con: int = int(s.get("constitution", 10))
	var intel: int = int(s.get("intellect", 10))
	var spr: int = int(s.get("spirit", 10))
	return {
		"atk": str_v,
		"def": maxi(0, con - 10),
		"spd": maxi(1, agi / 2),
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
	var con: int = int(stats.get("constitution", 10))
	var health_gain: int = 5 + maxi(0, con - 10) / 2
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
