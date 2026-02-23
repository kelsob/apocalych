extends Resource
class_name PartyMember

## Party Member - represents a single party member with race, class, and name

# Character identity
@export var member_name: String = ""
@export var race: Race = null
@export var class_resource: Class = null

# Character progression
@export var level: int = 1
@export var experience: int = 0
@export var experience_to_next_level: int = 100  # XP needed for level 2

# Character health
@export var max_health: int = 10
@export var current_health: int = 10

# Character inventory: item_id -> count
var inventory: Dictionary = {}

# Equipped weapon (stat stick, tiered with enchantment slots)
var weapon: Weapon = null

# Equipped armour (single slot, tiered like weapons)
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

## Remove items from this character's inventory. Returns true if removed (at least one).
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

## Get how many of an item this character has
func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

## Check if character has at least one of the item
func has_item(item_id: String) -> bool:
	return inventory.get(item_id, 0) > 0

## Get all item IDs this character owns (with count > 0)
func get_inventory_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in inventory.keys():
		if inventory[k] > 0:
			ids.append(str(k))
	return ids

## Initialize a new party member with starting values based on their stats
## Call this after setting race and class
func initialize():
	level = 1
	experience = 0
	experience_to_next_level = 100
	if weapon == null:
		weapon = Weapon.create_default()
	if armour == null:
		armour = Armour.create_default()
	
	# Calculate max health: base 10 + constitution modifier
	var stats = get_final_stats()
	var constitution = stats.get("constitution", 10)
	var con_modifier = _get_ability_modifier(constitution)
	max_health = 10 + con_modifier
	current_health = max_health
	
	print("Initialized %s: Level %d, Max HP: %d" % [member_name, level, max_health])

## Weapon type name from class for display (e.g. "Bow", "Sword"). Default "Weapon" if no class or unset.
func get_weapon_type() -> String:
	if class_resource and class_resource.weapon_type and not class_resource.weapon_type.is_empty():
		return class_resource.weapon_type
	return "Weapon"

## Get final stats combining race base stats and class modifiers
func get_final_stats() -> Dictionary:
	var stats = {}
	
	if race and race.base_stats:
		stats = race.base_stats.duplicate()
	
	if class_resource and class_resource.stat_modifiers:
		for stat in class_resource.stat_modifiers:
			if stats.has(stat):
				stats[stat] += class_resource.stat_modifiers[stat]
			else:
				stats[stat] = class_resource.stat_modifiers[stat]
	
	return stats

## Calculate D&D-style ability modifier from stat value
## 10-11 = +0, 12-13 = +1, 14-15 = +2, etc.
func _get_ability_modifier(stat_value: int) -> int:
	return (stat_value - 10) / 2

## Take damage and return true if still alive
func take_damage(amount: int) -> bool:
	current_health = max(0, current_health - amount)
	return current_health > 0

## Heal and cap at max health
func heal(amount: int):
	current_health = min(max_health, current_health + amount)

## Check if character is alive
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

## Gain experience and level up if threshold reached
func gain_experience(amount: int):
	experience += amount
	
	# Check for level up
	while experience >= experience_to_next_level:
		level_up()

## Level up the character
func level_up():
	level += 1
	experience -= experience_to_next_level
	
	# Increase XP requirement for next level (exponential scaling)
	experience_to_next_level = int(100 * pow(1.5, level - 1))
	
	# Increase max health on level up (base 5 + con modifier per level)
	var stats = get_final_stats()
	var constitution = stats.get("constitution", 10)
	var con_modifier = _get_ability_modifier(constitution)
	var health_gain = 5 + con_modifier
	max_health += health_gain
	current_health = max_health  # Full heal on level up
	
	print("%s leveled up to level %d! Max HP: %d (+%d)" % [member_name, level, max_health, health_gain])
