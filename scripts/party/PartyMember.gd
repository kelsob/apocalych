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

## Initialize a new party member with starting values based on their stats
## Call this after setting race and class
func initialize():
	level = 1
	experience = 0
	experience_to_next_level = 100
	
	# Calculate max health: base 10 + constitution modifier
	var stats = get_final_stats()
	var constitution = stats.get("constitution", 10)
	var con_modifier = _get_ability_modifier(constitution)
	max_health = 10 + con_modifier
	current_health = max_health
	
	print("Initialized %s: Level %d, Max HP: %d" % [member_name, level, max_health])

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
