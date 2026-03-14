extends Node

## EventManager - Data-driven event system for narrative events
## Loads events from JSON, selects events by biome/prerequisites, filters choices, applies effects

# Event registry: id -> event Dictionary
var events: Dictionary = {}

# Follow-up events: id -> event Dictionary. Only eligible when party has event's trigger_tag.
var followup_events: Dictionary = {}

# Track one-shot events that have been seen
var seen_one_shot_events: Array[String] = []

## Holds combat_outcomes from the event that triggered the current combat.
## Set by EventLog before apply_effects, read by Main after combat ends, then cleared.
var pending_combat_outcomes: Dictionary = {}

## Character (non-bulk) item rewards that need player assignment via ItemReward UI.
## Populated by _apply_give_item, drained by EventLog after apply_effects.
var pending_item_rewards: Array = []

## XP animation sequences populated before gain_experience/level_up modifies the member.
## Keyed by PartyMember reference. Read and cleared by CharacterDetails.refresh_xp().
var _xp_animation_data: Dictionary = {}

# Seedable RNG for deterministic event selection
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Party state reference (will be set by external systems)
var party_state: Dictionary = {}

## Debug: fallback when Main is not in tree. Prefer setting event_debug_force / event_debug_id / debug_event_selection on Main (inspector).
var debug_force_event: bool = false
var debug_event_id: String = ""

# Debug helper
func debug_print(msg: String):
	print(msg)

func _log_selection(msg: String) -> void:
	var main: Node = _get_main_node()
	if main and "debug_event_selection" in main and main.debug_event_selection:
		print("EventManager [SELECT]: %s" % msg)

func _ready():
	# Initialize RNG with a seed (can be set externally for determinism)
	rng.randomize()
	
	# Automatically load all events from the events directory
	load_events_from_directory("res://events")
	# Load follow-up events (tag-gated, separate pool)
	load_followup_events_from_json("res://events/followup_events.json")

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

## Load follow-up events from a single JSON file. Each event must have "id" and "trigger_tag".
## Follow-up events are stored separately and only considered when party has the trigger_tag.
func load_followup_events_from_json(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EventManager: Could not open follow-up events file: " + path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("EventManager: Failed to parse follow-up events JSON: " + json.get_error_message())
		return false
	
	var data = json.data
	if not data is Array:
		push_error("EventManager: Follow-up events JSON root must be an array")
		return false
	
	var loaded_count = 0
	for event in data:
		if not event.has("id"):
			push_error("EventManager: Follow-up event missing 'id' field, skipping")
			continue
		if not event.has("trigger_tag"):
			push_error("EventManager: Follow-up event '%s' missing 'trigger_tag' field, skipping" % event.get("id", ""))
			continue
		if followup_events.has(event.id):
			push_warning("EventManager: Duplicate follow-up event ID '%s', overwriting" % event.id)
		followup_events[event.id] = event
		loaded_count += 1
	
	print("EventManager: Loaded %d follow-up events from %s" % [loaded_count, path])
	return true

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

	# min_gold: party must have at least this much gold (for town entry, etc.)
	if condition.has("min_gold"):
		var min_gold = condition.min_gold
		if party.get("party_gold", 0) < min_gold:
			return false

	return true

## Pick an event for a node based on biome and prerequisites
func pick_event_for_node(biome: String, party: Dictionary, node_state: Dictionary = {}) -> Dictionary:
	# Return empty dict if no events are loaded
	if events.is_empty():
		push_warning("EventManager: No events loaded, cannot pick random event")
		return {}

	# Build party state and eligible follow-ups first (needed for "force steps aside" when follow-up eligible)
	var party_state_dict = _build_party_state(party)
	var is_town_node: bool = node_state.get("is_town", false)
	
	_log_selection("Node: biome=%s is_town=%s party_tags=%s" % [biome, is_town_node, str(party_state_dict.get("tags", []))])
	
	var eligible_followup_ids: Array[String] = []
	for event_id in followup_events.keys():
		var followup = followup_events[event_id]
		var trigger_tag: String = followup.get("trigger_tag", "")
		if trigger_tag.is_empty():
			_log_selection("  follow-up '%s': skip (no trigger_tag)" % event_id)
			continue
		if not party_state_dict.has("tags") or trigger_tag not in party_state_dict.tags:
			_log_selection("  follow-up '%s': skip (party lacks tag '%s')" % [event_id, trigger_tag])
			continue
		if followup.get("one_shot", true) and event_id in seen_one_shot_events:
			_log_selection("  follow-up '%s': skip (one_shot already seen)" % event_id)
			continue
		if followup.has("biomes"):
			var event_biomes = followup.biomes
			if event_biomes is Array and event_biomes.size() > 0 and biome not in event_biomes:
				_log_selection("  follow-up '%s': skip (biome '%s' not in %s)" % [event_id, biome, str(event_biomes)])
				continue
		if is_town_node and not followup.get("town_entry", false):
			_log_selection("  follow-up '%s': skip (town node, event not town_entry)" % event_id)
			continue
		if not is_town_node and followup.get("town_entry", false):
			_log_selection("  follow-up '%s': skip (not town, event is town_entry only)" % event_id)
			continue
		eligible_followup_ids.append(event_id)
		_log_selection("  follow-up '%s': ELIGIBLE (tag=%s)" % [event_id, trigger_tag])
	
	_log_selection("Eligible follow-ups: %d — %s" % [eligible_followup_ids.size(), str(eligible_followup_ids)])
	
	# Debug override: prefer Main's scene-tree exports. Steps aside when any follow-up is eligible so you can test follow-up flow.
	var force_event: bool = debug_force_event
	var force_id: String = debug_event_id
	var main: Node = _get_main_node()
	if main and "event_debug_force" in main:
		if main.event_debug_force:
			force_event = true
			force_id = main.event_debug_id
	if force_event and not force_id.is_empty():
		if eligible_followup_ids.size() > 0:
			_log_selection("Force override SKIPPED — follow-up(s) eligible, using normal selection")
			print("EventManager [DEBUG]: Follow-up(s) eligible (%s), skipping force — using normal selection" % str(eligible_followup_ids))
		else:
			if events.has(force_id):
				print("EventManager [DEBUG]: Forcing event '%s'" % force_id)
				return events[force_id]
			elif followup_events.has(force_id):
				print("EventManager [DEBUG]: Forcing follow-up event '%s'" % force_id)
				return followup_events[force_id]
			else:
				push_warning("EventManager: debug event id '%s' not found in loaded events or follow-up events" % force_id)
	elif force_event and force_id.is_empty():
		push_warning("EventManager: debug force event is true but event_debug_id / debug_event_id is not set")
	
	# Step 1: Follow-up events — one 50/50 roll per eligible; first hit wins.
	eligible_followup_ids.sort()
	for event_id in eligible_followup_ids:
		var roll: float = rng.randf()
		var passed: bool = roll < 0.5
		_log_selection("  roll '%s': %.3f → %s" % [event_id, roll, "PASS (< 0.5)" if passed else "fail (>= 0.5)"])
		if passed:
			var selected = followup_events[event_id]
			if selected.get("one_shot", true):
				seen_one_shot_events.append(selected.id)
			_log_selection("SELECTED (follow-up): %s" % event_id)
			return selected
	
	_log_selection("No follow-up won (all rolls failed). Using normal event pool.")
	
	# Step 2: No follow-up won; build pool from normal events only
	var eligible_events: Array = []
	for event_id in events.keys():
		var event = events[event_id]
		
		if event.get("one_shot", false) and event_id in seen_one_shot_events:
			continue
		if event.has("biomes"):
			var event_biomes = event.biomes
			if event_biomes is Array and event_biomes.size() > 0 and biome not in event_biomes:
				continue
		if is_town_node and not event.get("town_entry", false):
			continue
		if not is_town_node and event.get("town_entry", false):
			continue
		if event.has("prereqs"):
			if not condition_passes(event.prereqs, party_state_dict):
				continue
		var weight = event.get("weight", 1)
		eligible_events.append({"event": event, "weight": weight})
	
	if eligible_events.is_empty():
		_log_selection("Normal pool: 0 eligible → return {}")
		return {}
	
	var total_weight = 0
	for item in eligible_events:
		total_weight += item.weight
	
	var random_value = rng.randf_range(0, total_weight)
	var accumulated_weight = 0.0
	
	_log_selection("Normal pool: %d eligible, total_weight=%d, roll=%.3f" % [eligible_events.size(), total_weight, random_value])
	
	for item in eligible_events:
		accumulated_weight += item.weight
		if random_value <= accumulated_weight:
			var selected_event = item.event
			if selected_event.get("one_shot", false):
				seen_one_shot_events.append(selected_event.id)
			_log_selection("SELECTED (normal): %s" % selected_event.get("id", ""))
			return selected_event
	
	_log_selection("SELECTED (normal fallback): %s" % eligible_events[0].event.get("id", ""))
	return eligible_events[0].event

## Present an event - returns event with filtered choices
func present_event(event: Dictionary, party: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}
	
	var party_state_dict = _build_party_state(party)
	
	# Filter choices by conditions (condition = hide entirely if not met)
	var filtered_choices: Array[Dictionary] = []
	for choice in event.get("choices", []):
		if not choice.has("condition"):
			filtered_choices.append(choice)
		else:
			if condition_passes(choice.condition, party_state_dict):
				filtered_choices.append(choice)
	
	# requires_item = keep visible but mark disabled if party lacks the item
	for i in range(filtered_choices.size()):
		var choice = filtered_choices[i]
		if choice.has("requires_item"):
			var req = choice.requires_item
			var req_item_id: String = str(req.get("item_id", ""))
			var req_count: int = int(req.get("count", 1))
			if not _party_has_item(req_item_id, req_count):
				var disabled_choice = choice.duplicate(true)
				disabled_choice["disabled"] = true
				filtered_choices[i] = disabled_choice
	
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

## Pick a weighted-random outcome from a choice's outcomes array.
## Each outcome dict should have a "weight" field (defaults to 1 if absent).
## Returns the winning outcome Dictionary, or an empty Dictionary if the array is empty.
func pick_weighted_outcome(outcomes: Array) -> Dictionary:
	if outcomes.is_empty():
		return {}

	var total_weight: float = 0.0
	for outcome in outcomes:
		total_weight += float(outcome.get("weight", 1))

	if total_weight <= 0.0:
		return outcomes[0]

	var roll: float = rng.randf_range(0.0, total_weight)
	var accumulated: float = 0.0
	for outcome in outcomes:
		accumulated += float(outcome.get("weight", 1))
		if roll <= accumulated:
			return outcome

	# Fallback — should only be reached due to float precision edge cases
	return outcomes[outcomes.size() - 1]

## Apply effects from a choice
func apply_effects(effects: Array, party: Dictionary, node_state: Dictionary = {}):
	debug_print("SECRET PATH: EventManager apply_effects() called with %d effects" % effects.size())
	
	if not effects is Array:
		debug_print("SECRET PATH: Effects is not an array!")
		return
	
	for effect in effects:
		if not effect.has("type"):
			push_warning("SECRET PATH: EventManager Effect missing 'type' field, skipping")
			continue
		
		debug_print("SECRET PATH: Processing effect type: %s" % effect.type)
		
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
			
			"reveal_secrets":
				_apply_reveal_secrets(effect, party, node_state)

			"pay_gold":
				_apply_pay_gold(effect, party, node_state)

			"give_gold":
				_apply_give_gold(effect, party, node_state)

			"open_town":
				_apply_open_town(effect, party, node_state)

			"open_vendor":
				_apply_open_vendor(effect, party, node_state)

			"advance_time":
				_apply_advance_time(effect)

			"consume_item":
				_apply_consume_item(effect, party)

			"give_item_from_pool":
				_apply_give_item_from_pool(effect, party)

			"give_xp":
				_apply_give_xp(effect, party)

			"heal_party":
				_apply_heal_party(effect, party)
			
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

	# Party gold (for conditions like min_gold)
	state.party_gold = party.get("party_gold", 0)
	
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

	var count: int
	if effect.has("min_count") and effect.has("max_count"):
		count = rng.randi_range(int(effect.min_count), int(effect.max_count))
	else:
		count = int(effect.get("count", 1))
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: give_item requires Main node")
		return
	if not ItemDatabase.has_item(effect.item_id):
		push_warning("EventManager: Unknown item_id '%s'" % effect.item_id)
		return
	var item := ItemDatabase.get_item(effect.item_id)

	# Resource items go to party-wide store (target is irrelevant for bulk)
	if ItemDatabase.is_bulk_loot(effect.item_id):
		var added := 0
		for i in count:
			if main.add_party_resource(effect.item_id, 1):
				added += 1
		if added > 0:
			print("EventManager: Gave %s x%d to party resources" % [item.name, added])
		return

	# Non-bulk items are queued for player assignment via ItemReward UI
	if main.current_party_members.is_empty():
		push_warning("EventManager: give_item requires party members for non-resource items")
		return
	pending_item_rewards.append({ "item_id": effect.item_id, "count": count, "item": item })

## Returns all queued character item rewards and clears the queue.
## Called by EventLog after apply_effects so ItemReward UI can be shown.
func drain_pending_item_rewards() -> Array:
	var drained := pending_item_rewards.duplicate()
	pending_item_rewards.clear()
	return drained

## Actually grants a character item to the chosen member after the player picks via ItemReward UI.
func fulfill_item_reward(item_id: String, count: int, member: PartyMember) -> void:
	if not ItemDatabase.has_item(item_id):
		push_warning("EventManager: fulfill_item_reward unknown item_id '%s'" % item_id)
		return
	var item := ItemDatabase.get_item(item_id)
	var main: Node = _get_main_node()
	var party_total: int = 0
	if main:
		for m in main.current_party_members:
			party_total += m.get_item_count(item_id)
	var capacity_headroom: int = 999
	if item.capacity > 0:
		capacity_headroom = item.capacity - party_total
	if capacity_headroom <= 0:
		print("EventManager: %s is at capacity, could not give to %s" % [item.name, member.member_name])
		return
	var to_add: int = mini(count, capacity_headroom)
	var added := 0
	for i in to_add:
		if member.add_item(item_id, 1):
			added += 1
	if added > 0:
		print("EventManager: Gave %s x%d to %s" % [item.name, added, member.member_name])

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
	
	# Load encounter resource
	var encounter_path = "res://resources/encounters/%s.tres" % effect.encounter_id
	var encounter = load(encounter_path) as CombatEncounter
	
	if not encounter:
		push_error("EventManager: Could not load encounter: " + encounter_path)
		return
	
	# Get Main node to access party members
	var root: Window = get_tree().root
	var main: Node = null
	
	for child in root.get_children():
		if child.name == "Main" or child.is_in_group("main"):
			main = child
			break
	
	if not main:
		push_error("EventManager: Could not find Main node for combat")
		return
	
	# Hide event log and map UI during combat
	main.ui_controller.event_log.visible = false
	main.map_generator.visible = false
	main.ui_controller.map_ui.visible = false
	
	# Load and show combat scene
	var combat_scene_path = "res://scenes/combat/CombatScene.tscn"
	if not ResourceLoader.exists(combat_scene_path):
		push_error("EventManager: Combat scene not found at: " + combat_scene_path)
		push_error("  Please create the combat scene first (see COMBAT_SETUP_GUIDE.md)")
		return
	
	var combat_scene = load(combat_scene_path).instantiate()
	print("EventManager: Combat scene instantiated")
	
	# Add combat scene to UIController CanvasLayer so it locks to camera
	main.ui_controller.add_child(combat_scene)
	print("EventManager: Combat scene added to UIController")
	
	# Wait one frame to ensure scene is fully in tree
	await get_tree().process_frame
	
	print("EventManager: Starting combat with %d party members" % main.current_party_members.size())
	
	# Start combat via CombatController
	CombatController.start_combat_from_encounter(encounter, main.current_party_members)

func _apply_script_hook(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	if not effect.has("hook_name"):
		push_warning("EventManager: script_hook effect missing 'hook_name' field")
		return
	
	var main := _get_main_node()
	if not main:
		return
	
	match effect.hook_name:
		"open_merchant_ui":
			main.open_vendor_screen(null)
		"restart_game":
			get_tree().reload_current_scene()
		"go_to_main_menu":
			main.game_started = false
			main.show_menu(main.GameState.MAIN_MENU)
		"quit_game":
			get_tree().quit()
		_:
			push_warning("EventManager: Unknown script hook '%s'" % effect.hook_name)

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

func _apply_pay_gold(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	var amount: int = int(effect.get("amount", 0))
	if amount <= 0:
		return
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: pay_gold could not find Main")
		return
	main.party_gold = max(0, main.party_gold - amount)
	print("EventManager: Paid %d gold (remaining: %d)" % [amount, main.party_gold])

func _apply_give_gold(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	var amount: int
	if effect.has("min_amount") and effect.has("max_amount"):
		amount = rng.randi_range(int(effect.min_amount), int(effect.max_amount))
	else:
		amount = int(effect.get("amount", 0))
	if amount <= 0:
		return
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: give_gold could not find Main")
		return
	main.party_gold = max(0, main.party_gold + amount)
	print("EventManager: Gave %d gold (total: %d)" % [amount, main.party_gold])

func _apply_open_town(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	var current_node = node_state.get("current_node", null)
	if current_node == null:
		push_warning("EventManager: open_town effect requires current_node in node_state")
		return
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: open_town could not find Main")
		return
	var force_all_services: bool = effect.get("show_all_services", false)
	main.ui_controller.event_log.close()
	main.map_generator.visible = false
	main.ui_controller.map_ui.visible = false
	main.open_town_screen(current_node, force_all_services)

func _apply_open_vendor(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	var main: Node = _get_main_node()
	if not main:
		return
	var vendor_item_ids: Array = effect.get("item_ids", [])
	main.ui_controller.event_log.close()
	main.map_generator.visible = false
	main.ui_controller.map_ui.visible = false
	main.open_vendor_screen(null, vendor_item_ids)

func _apply_advance_time(effect: Dictionary) -> void:
	if not effect.has("amount"):
		push_warning("EventManager: advance_time effect missing 'amount' field")
		return
	var amount: float = float(effect.amount)
	if amount <= 0.0:
		return
	if TimeManager:
		TimeManager.advance_time_from_event(amount)

## Check whether the party currently holds at least `count` of the given item
func _party_has_item(item_id: String, count: int) -> bool:
	if item_id.is_empty():
		return false
	var main := _get_main_node()
	if not main:
		return false
	if ItemDatabase.is_bulk_loot(item_id):
		return main.get_party_resource_count(item_id) >= count
	# Non-bulk: sum across all party members
	var total := 0
	for m in main.current_party_members:
		total += m.get_item_count(item_id)
	return total >= count

func _apply_consume_item(effect: Dictionary, party: Dictionary):
	if not effect.has("item_id"):
		push_warning("EventManager: consume_item effect missing 'item_id' field")
		return
	var item_id: String = str(effect.item_id)
	var count: int = int(effect.get("count", 1))
	if count <= 0:
		return
	var main := _get_main_node()
	if not main:
		push_warning("EventManager: consume_item could not find Main")
		return
	if ItemDatabase.is_bulk_loot(item_id):
		if not main.remove_party_resource(item_id, count):
			push_warning("EventManager: consume_item – not enough %s (needed %d)" % [item_id, count])
		else:
			print("EventManager: Consumed %s x%d" % [item_id, count])
	else:
		# Remove from whichever party members hold the item
		var remaining := count
		for m in main.current_party_members:
			if remaining <= 0:
				break
			var has: int = m.get_item_count(item_id)
			if has > 0:
				var to_remove := mini(remaining, has)
				m.remove_item(item_id, to_remove)
				remaining -= to_remove
		if remaining > 0:
			push_warning("EventManager: consume_item – could not consume full quantity of %s" % item_id)

## Pick a random item_id from the pool, then give a fixed or random count of it.
## Supports all the same count/min_count/max_count options as give_item.
## JSON: { "type": "give_item_from_pool", "pool": ["health_potion", "camping_supplies"], "min_count": 1, "max_count": 3 }
func _apply_give_item_from_pool(effect: Dictionary, party: Dictionary):
	var pool: Array = effect.get("pool", [])
	if pool.is_empty():
		push_warning("EventManager: give_item_from_pool effect has empty 'pool' array")
		return
	var item_id: String = str(pool[rng.randi() % pool.size()])
	var synthetic_effect: Dictionary = effect.duplicate()
	synthetic_effect["item_id"] = item_id
	_apply_give_item(synthetic_effect, party)

## Grant XP to party members.
## target: "all" | "random" | integer index. force_level_up skips XP math and calls level_up() directly.
## JSON: { "type": "give_xp", "amount": 75, "target": "all" }
##       { "type": "give_xp", "force_level_up": true, "target": "random" }
func _apply_give_xp(effect: Dictionary, party: Dictionary):
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: give_xp could not find Main")
		return
	var alive: Array = main.current_party_members.filter(func(m): return m.is_alive())
	if alive.is_empty():
		return
	var force_level_up: bool = effect.get("force_level_up", false)
	var amount: int = int(effect.get("amount", 0))
	var target = effect.get("target", "all")
	var targets: Array = _resolve_member_targets(target, alive)
	for member in targets:
		if force_level_up:
			# Snapshot for animation: bar fills → level increments → bar resets to 0
			var new_level: int = member.level + 1
			var new_to_next: int = int(100 * pow(1.5, new_level - 1))
			_xp_animation_data[member] = [
				{"level": member.level, "experience": member.experience, "experience_to_next_level": member.experience_to_next_level},
				{"level": new_level, "experience": 0, "experience_to_next_level": new_to_next}
			]
			member.level_up()
			print("EventManager: Force level-up → %s is now level %d" % [member.member_name, member.level])
		elif amount > 0:
			_xp_animation_data[member] = member.simulate_xp_gain(amount)
			member.gain_experience(amount)
			print("EventManager: Gave %d XP to %s" % [amount, member.member_name])

## Heal party members.
## target: "all" | "random" | integer index.
## amount: integer (flat heal) | "full" (restore to max). percent: 0–100 (percent of max HP).
## JSON: { "type": "heal_party", "target": "all", "amount": 20 }
##       { "type": "heal_party", "target": "random", "amount": "full" }
##       { "type": "heal_party", "target": "all", "percent": 50 }
func _apply_heal_party(effect: Dictionary, party: Dictionary):
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: heal_party could not find Main")
		return
	var alive: Array = main.current_party_members.filter(func(m): return m.is_alive())
	if alive.is_empty():
		return
	var target = effect.get("target", "all")
	var targets: Array = _resolve_member_targets(target, alive)
	for member in targets:
		var healed: int = 0
		if effect.has("percent"):
			healed = int(member.max_health * float(effect.percent) / 100.0)
			member.heal(healed)
		elif effect.get("amount", "") == "full":
			healed = member.max_health - member.current_health
			member.heal(member.max_health)
		else:
			healed = int(effect.get("amount", 0))
			member.heal(healed)
		print("EventManager: Healed %s for %d HP (%d/%d)" % [member.member_name, healed, member.current_health, member.max_health])

## Resolve a target field into an Array of PartyMember references from the alive pool.
## target: "all" → all alive members | "random" → one random alive member | int → member at that index (if alive)
func _resolve_member_targets(target, alive: Array) -> Array:
	if target == "all":
		return alive
	if target == "random":
		return [alive[rng.randi() % alive.size()]]
	# Integer index into current_party_members (not the alive-filtered list)
	var main: Node = _get_main_node()
	if main and typeof(target) == TYPE_INT or (typeof(target) == TYPE_STRING and target.is_valid_int()):
		var idx: int = int(target)
		if idx >= 0 and idx < main.current_party_members.size():
			var m = main.current_party_members[idx]
			if m.is_alive():
				return [m]
	push_warning("EventManager: _resolve_member_targets: unrecognised target '%s', defaulting to random" % str(target))
	return [alive[rng.randi() % alive.size()]]

func _get_main_node() -> Node:
	var root: Window = get_tree().root
	for child in root.get_children():
		if child.name == "Main" or child.is_in_group("main"):
			return child
	return null

func _apply_reveal_secrets(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	debug_print("SECRET PATH: === EventManager _apply_reveal_secrets() called ===")
	
	# EventManager is an autoload, find Main node first
	var root: Window = get_tree().root
	var main: Node = null
	
	# Search through root's children for Main
	for child in root.get_children():
		if child.name == "Main" or child.is_in_group("main"):
			main = child
			break
	
	if main == null:
		push_warning("SECRET PATH: EventManager could not find Main node")
		return
	
	debug_print("SECRET PATH: EventManager found Main node")
	
	# Access MapGenerator through Main's property
	if not main.map_generator:
		push_warning("SECRET PATH: Main node does not have map_generator property")
		return
	
	debug_print("SECRET PATH: EventManager found MapGenerator via Main.map_generator")
	debug_print("SECRET PATH: EventManager calling reveal_secret_paths_at_current_location()...")
	main.map_generator.reveal_secret_paths_at_current_location()
	debug_print("SECRET PATH: EventManager DONE - revealed secret paths at current location")
