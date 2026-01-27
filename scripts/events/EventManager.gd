extends Node

## EventManager - Data-driven event system for narrative events
## Loads events from JSON, selects events by biome/prerequisites, filters choices, applies effects

# Event registry: id -> event Dictionary
var events: Dictionary = {}

# Track one-shot events that have been seen
var seen_one_shot_events: Array[String] = []

# Seedable RNG for deterministic event selection
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Party state reference (will be set by external systems)
var party_state: Dictionary = {}

func _ready():
	# Initialize RNG with a seed (can be set externally for determinism)
	rng.randomize()
	
	# Automatically load all events from the events directory
	load_events_from_directory("res://events")

## Set the seed for deterministic event selection
func set_seed(seed_value: int):
	rng.seed = seed_value

## Load events from a JSON file
func load_events_from_json(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EventManager: Could not open events file: " + path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("EventManager: Failed to parse JSON: " + json.get_error_message())
		return false
	
	var data = json.data
	if not data is Array:
		push_error("EventManager: JSON root must be an array of events")
		return false
	
	var loaded_count = 0
	for event in data:
		if not event.has("id"):
			push_error("EventManager: Event missing 'id' field, skipping")
			continue
		
		# Check for duplicate IDs
		if events.has(event.id):
			push_warning("EventManager: Duplicate event ID '%s', overwriting previous event" % event.id)
		
		events[event.id] = event
		loaded_count += 1
	
	print("EventManager: Loaded %d events from %s (total: %d)" % [loaded_count, path, events.size()])
	return true

## Load all event files from a directory
func load_events_from_directory(dir_path: String) -> int:
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_error("EventManager: Could not open directory: " + dir_path)
		return 0
	
	var loaded_count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path = dir_path + "/" + file_name
			if load_events_from_json(full_path):
				loaded_count += 1
		file_name = dir.get_next()
	
	print("EventManager: Loaded %d event files from directory" % loaded_count)
	return loaded_count

## Check if a condition passes given party state
func condition_passes(condition: Dictionary, party: Dictionary) -> bool:
	# requires_tags: all tags must be present
	if condition.has("requires_tags"):
		var required_tags = condition.requires_tags
		if required_tags is Array:
			for tag in required_tags:
				if not party.has("tags") or not party.tags.has(tag):
					return false
	
	# forbids_tags: none of these tags can be present
	if condition.has("forbids_tags"):
		var forbidden_tags = condition.forbids_tags
		if forbidden_tags is Array:
			for tag in forbidden_tags:
				if party.has("tags") and party.tags.has(tag):
					return false
	
	# requires_any: at least one of these must be present
	if condition.has("requires_any"):
		var any_tags = condition.requires_any
		if any_tags is Array:
			var found_any = false
			for tag in any_tags:
				if party.has("tags") and party.tags.has(tag):
					found_any = true
					break
			if not found_any:
				return false
	
	# min_reputation: check minimum reputation with a faction
	if condition.has("min_reputation"):
		var rep_checks = condition.min_reputation
		if rep_checks is Dictionary:
			for faction in rep_checks:
				var min_rep = rep_checks[faction]
				var current_rep = party.get("reputation", {}).get(faction, 0)
				if current_rep < min_rep:
					return false
	
	# variables: check min/max values
	if condition.has("variables"):
		var var_checks = condition.variables
		if var_checks is Dictionary:
			for var_name in var_checks:
				var var_condition = var_checks[var_name]
				var current_value = party.get("variables", {}).get(var_name, 0)
				
				if var_condition.has("min") and current_value < var_condition.min:
					return false
				if var_condition.has("max") and current_value > var_condition.max:
					return false
	
	return true

## Pick an event for a node based on biome and prerequisites
func pick_event_for_node(biome: String, party: Dictionary, node_state: Dictionary = {}) -> Dictionary:
	# For now, just always return the dangerous placeholder event (for testing)
	return events.get("dangerous_location_event", {})

## Present an event - returns event with filtered choices
func present_event(event: Dictionary, party: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}
	
	var party_state_dict = _build_party_state(party)
	
	# Filter choices by conditions
	var filtered_choices: Array[Dictionary] = []
	for choice in event.get("choices", []):
		if not choice.has("condition"):
			# No condition means always available
			filtered_choices.append(choice)
		else:
			if condition_passes(choice.condition, party_state_dict):
				filtered_choices.append(choice)
	
	# Create a copy of the event with filtered choices
	var presented_event = event.duplicate(true)
	presented_event.choices = filtered_choices
	
	# Interpolate text
	if presented_event.has("text"):
		presented_event.text = _interpolate_text(presented_event.text, party)
	
	for i in range(presented_event.choices.size()):
		if presented_event.choices[i].has("text"):
			presented_event.choices[i].text = _interpolate_text(presented_event.choices[i].text, party)
	
	return presented_event

## Apply effects from a choice
func apply_effects(effects: Array, party: Dictionary, node_state: Dictionary = {}):
	if not effects is Array:
		return
	
	for effect in effects:
		if not effect.has("type"):
			push_warning("EventManager: Effect missing 'type' field, skipping")
			continue
		
		match effect.type:
			"add_tag":
				_apply_add_tag(effect, party)
			
			"remove_tag":
				_apply_remove_tag(effect, party)
			
			"give_item":
				_apply_give_item(effect, party)
			
			"change_reputation":
				_apply_change_reputation(effect, party)
			
			"change_stat":
				_apply_change_stat(effect, party)
			
			"set_variable":
				_apply_set_variable(effect, party)
			
			"unlock_event":
				_apply_unlock_event(effect)
			
			"start_combat":
				_apply_start_combat(effect, party, node_state)
			
			"script_hook":
				_apply_script_hook(effect, party, node_state)
			
			"set_rest_state":
				_apply_set_rest_state(effect, node_state)
			
			_:
				push_warning("EventManager: Unknown effect type: " + str(effect.type))

## Build party state dictionary for condition checking
func _build_party_state(party: Dictionary) -> Dictionary:
	var state = {}
	
	# Tags from TagManager
	if TagManager:
		state.tags = TagManager.get_all_tags()
	else:
		state.tags = []
	
	# Reputation (if party dict has it)
	if party.has("reputation"):
		state.reputation = party.reputation
	else:
		state.reputation = {}
	
	# Variables (if party dict has it)
	if party.has("variables"):
		state.variables = party.variables
	else:
		state.variables = {}
	
	# Party members info (for interpolation)
	if party.has("members"):
		state.members = party.members
		if party.members.size() > 0:
			state.leader_name = party.members[0].get("name", "Unknown")
	
	return state

## Interpolate {{variable}} placeholders in text
func _interpolate_text(text: String, party: Dictionary) -> String:
	var result = text
	var party_state_dict = _build_party_state(party)
	
	# Find all {{variable}} patterns
	var regex = RegEx.new()
	regex.compile("\\{\\{([^}]+)\\}\\}")
	
	var matches = regex.search_all(text)
	for match in matches:
		var full_match = match.get_string(0)  # {{variable}}
		var var_path = match.get_string(1)    # variable
		
		var value = _get_nested_value(var_path, party_state_dict, party)
		result = result.replace(full_match, str(value))
	
	return result

## Get nested value from dictionary using dot notation (e.g., "party.leader_name")
func _get_nested_value(path: String, state: Dictionary, party: Dictionary) -> String:
	var parts = path.split(".")
	var current = state
	
	# Handle "party." prefix
	if parts[0] == "party":
		current = party
		parts = parts.slice(1)
	
	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		elif current is Array:
			# Handle array index access (e.g., "members.0.name")
			var index = part.to_int()
			if index >= 0 and index < current.size():
				current = current[index]
			else:
				return "{{" + path + "}}"  # Return original if index out of bounds
		else:
			return "{{" + path + "}}"  # Return original if not found
	
	return str(current)

## Effect implementations

func _apply_add_tag(effect: Dictionary, party: Dictionary):
	if not effect.has("tag"):
		push_warning("EventManager: add_tag effect missing 'tag' field")
		return
	
	if TagManager:
		TagManager.add_tag(effect.tag)
	else:
		push_warning("EventManager: TagManager not available for add_tag effect")

func _apply_remove_tag(effect: Dictionary, party: Dictionary):
	if not effect.has("tag"):
		push_warning("EventManager: remove_tag effect missing 'tag' field")
		return
	
	if TagManager:
		TagManager.remove_tag(effect.tag)
	else:
		push_warning("EventManager: TagManager not available for remove_tag effect")

func _apply_give_item(effect: Dictionary, party: Dictionary):
	if not effect.has("item_id"):
		push_warning("EventManager: give_item effect missing 'item_id' field")
		return
	
	var count = effect.get("count", 1)
	# TODO: Connect to inventory system
	print("EventManager: Would give item %s x%d" % [effect.item_id, count])

func _apply_change_reputation(effect: Dictionary, party: Dictionary):
	if not effect.has("faction") or not effect.has("amount"):
		push_warning("EventManager: change_reputation effect missing 'faction' or 'amount' field")
		return
	
	# TODO: Connect to reputation system
	print("EventManager: Would change reputation with %s by %d" % [effect.faction, effect.amount])

func _apply_change_stat(effect: Dictionary, party: Dictionary):
	if not effect.has("stat") or not effect.has("amount"):
		push_warning("EventManager: change_stat effect missing 'stat' or 'amount' field")
		return
	
	# TODO: Connect to party stat system
	print("EventManager: Would change stat %s by %d" % [effect.stat, effect.amount])

func _apply_set_variable(effect: Dictionary, party: Dictionary):
	if not effect.has("variable") or not effect.has("value"):
		push_warning("EventManager: set_variable effect missing 'variable' or 'value' field")
		return
	
	# TODO: Connect to variable storage system
	print("EventManager: Would set variable %s to %s" % [effect.variable, effect.value])

func _apply_unlock_event(effect: Dictionary):
	if not effect.has("event_id"):
		push_warning("EventManager: unlock_event effect missing 'event_id' field")
		return
	
	# Remove from seen_one_shot if it was one-shot
	if seen_one_shot_events.has(effect.event_id):
		seen_one_shot_events.erase(effect.event_id)
	
	print("EventManager: Unlocked event %s" % effect.event_id)

func _apply_start_combat(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	if not effect.has("encounter_id"):
		push_warning("EventManager: start_combat effect missing 'encounter_id' field")
		return
	
	# TODO: Connect to combat system
	print("EventManager: Would start combat encounter %s" % effect.encounter_id)

func _apply_script_hook(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	if not effect.has("hook_name"):
		push_warning("EventManager: script_hook effect missing 'hook_name' field")
		return
	
	# TODO: Connect to named hook system
	# This allows external systems to register named hooks
	print("EventManager: Would call script hook '%s'" % effect.hook_name)

func _apply_set_rest_state(effect: Dictionary, node_state: Dictionary):
	if not effect.has("allow_rest"):
		push_warning("EventManager: set_rest_state effect missing 'allow_rest' field")
		return
	
	# Get the current node from node_state
	var current_node = node_state.get("current_node", null)
	if current_node == null:
		push_warning("EventManager: set_rest_state effect requires 'current_node' in node_state")
		return
	
	# Set the rest state on the node
	var allow_rest = effect.allow_rest
	current_node.can_rest_here = allow_rest
	
	print("EventManager: Set rest state to %s at node %d" % [allow_rest, current_node.node_index])
