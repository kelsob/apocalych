extends Resource
class_name PartyMember

## Party Member - represents a single party member with race, class, and name

@export var member_name: String = ""
@export var race: Race = null
@export var class_resource: Class = null

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
