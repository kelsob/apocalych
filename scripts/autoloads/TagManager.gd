extends Node

## TagManager - manages party composition tags for event queries
## Tags are automatically generated from party composition

# Current active tags
var active_tags: Array[String] = []

## Update tags based on current party composition
func update_tags_from_party(party_members: Array[PartyMember]):
	active_tags.clear()
	
	if party_members.is_empty():
		return
	
	# Count races and classes
	var race_counts: Dictionary = {}
	var class_counts: Dictionary = {}
	
	for member in party_members:
		if member.race:
			var race_key = member.race.race_name.to_lower()
			race_counts[race_key] = race_counts.get(race_key, 0) + 1
		
		if member.class_resource:
			var class_key = member.class_resource.name.to_lower()
			class_counts[class_key] = class_counts.get(class_key, 0) + 1
	
	# Add race tags
	for race_key in race_counts:
		active_tags.append("<" + race_key + ">")
		# If all members are this race, add "all_" tag
		if race_counts[race_key] == party_members.size():
			active_tags.append("<all_" + race_key + ">")
	
	# Add class tags
	for class_key in class_counts:
		active_tags.append("<" + class_key + ">")
		# If all members are this class, add "all_" tag
		if class_counts[class_key] == party_members.size():
			active_tags.append("<all_" + class_key + ">")

## Check if a specific tag exists
func has_tag(tag: String) -> bool:
	return active_tags.has(tag)

## Check if any of the provided tags exist
func has_any_tag(tags: Array[String]) -> bool:
	for tag in tags:
		if active_tags.has(tag):
			return true
	return false

## Check if all of the provided tags exist
func has_all_tags(tags: Array[String]) -> bool:
	for tag in tags:
		if not active_tags.has(tag):
			return false
	return true

## Manually add a tag (for special cases)
func add_tag(tag: String):
	if not active_tags.has(tag):
		active_tags.append(tag)

## Manually remove a tag
func remove_tag(tag: String):
	var index = active_tags.find(tag)
	if index >= 0:
		active_tags.remove_at(index)

## Clear all tags
func clear_tags():
	active_tags.clear()

## Get all active tags (for debugging)
func get_all_tags() -> Array[String]:
	return active_tags.duplicate()
