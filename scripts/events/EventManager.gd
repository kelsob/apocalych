extends Node

## EventManager - Data-driven narrative events.
## Node arrival: `pick_event_for_node` → debug force (optional one-shot) → **tag_driven_event_pool**
## (events whose `prereqs` reference a current TagManager tag and pass filters) → weighted random →
## fallback `__tag_driven_pool_empty__` if the pool is empty.

# Event registry: id -> event Dictionary
var events: Dictionary = {}

# Track one-shot events that have been seen
var seen_one_shot_events: Array[String] = []

## Holds combat_outcomes from the event that triggered the current combat.
## Set by EventLog before apply_effects, read by Main after combat ends, then cleared.
var pending_combat_outcomes: Dictionary = {}

## Ordered UI queue for EventLog: gold/XP rows (`EventRewards`) + item pickers + item-choice bundles.
## Populated by give_gold, give_xp, give_item (non-bulk), give_item_choice (grant one); drained after each apply batch.
var pending_event_log_visual_queue: Array = []

## Substitution variables populated during apply_effects for use in outcome text.
## EventLog replaces {key} placeholders in outcome text with these values.
## Cleared at the start of each apply_effects call.
## "member" → name of the party member most recently selected by a random/single-target effect.
var text_vars: Dictionary = {}

## Set by EventStatCheck / EventChoiceContainer before `apply_effects` when resolving a stat challenge.
## Keys: `actor_index` (int), `actor_name` (String), `tier` (String). Cleared after `apply_effects`.
var stat_check_context: Dictionary = {}

## XP animation sequences populated before gain_experience/level_up modifies the member.
## Keyed by HeroCharacter reference. Read and cleared by CharacterDetails.refresh_xp().
var _xp_animation_data: Dictionary = {}

## Effects with `"timing": "on_event_close"` queue here; **`drain_effects_on_event_close`** runs them when the event UI session ends.
var pending_effects_on_event_close: Array = []

## Per-effect timing for nested steps (`EVENT_DESIGN.md`). Missing `timing` → **after_text** (matches legacy one-shot apply).
const EFFECT_TIMING_BEFORE_TEXT: String = "before_text"
const EFFECT_TIMING_AFTER_TEXT: String = "after_text"
const EFFECT_TIMING_ON_EVENT_CLOSE: String = "on_event_close"

# Seedable RNG for deterministic event selection
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Party state reference (will be set by external systems)
var party_state: Dictionary = {}

## Debug: fallback when Main is not in tree. Prefer Main exports. Cleared after one successful forced pick unless Main.event_debug_keep_forcing.
var debug_force_event: bool = false
var debug_event_id: String = ""

## When Main forces events: next slot to read from `event_debug_id_1` … `_3` (0–3). Reset when `event_debug_force` is off at pick time.
var _debug_sequence_slot: int = 0

## Last pick snapshot (always updated — inspect EventManager in Remote tree if console overflow drops prints).
var debug_last_pick_biome: String = ""
var debug_last_pick_is_town: bool = false
var debug_last_pick_selected_id: String = ""
var debug_last_pick_was_forced: bool = false
var debug_last_pick_eligible_count: int = 0
var debug_last_pick_rolled_pool_size: int = 0
var debug_last_pick_total_weight: float = 0.0
var debug_last_pick_roll: float = -1.0

# Debug helper
func debug_print(msg: String):
	print(msg)


func _event_pick_log_enabled(main: Node) -> bool:
	if main != null and "debug_event_selection" in main and main.debug_event_selection:
		return true
	return false


const EVENT_SELECTION_LOG_PREFIX := "event selection: "


func _event_pick_log(main: Node, msg: String) -> void:
	if _event_pick_log_enabled(main):
		print("%s%s" % [EVENT_SELECTION_LOG_PREFIX, msg])


## True if `event_debug_id_1`…`_3` still have a non-`__none__` id at or after the current sequence cursor (`_debug_sequence_slot` is next index to read on the next pick).
func _has_pending_non_none_sequence_slots(main_node: Node) -> bool:
	if main_node == null:
		return false
	var seq_slots: Array = [
		_main_debug_seq_export(main_node, "event_debug_id_1"),
		_main_debug_seq_export(main_node, "event_debug_id_2"),
		_main_debug_seq_export(main_node, "event_debug_id_3"),
	]
	for i in range(_debug_sequence_slot, 3):
		var cand: String = seq_slots[i]
		if cand != "__none__" and not cand.is_empty():
			return true
	return false


func _clear_debug_event_force_after_pick(main_node: Node, main_had_force: bool) -> void:
	var keep: bool = main_node != null and "event_debug_keep_forcing" in main_node and main_node.event_debug_keep_forcing
	if keep:
		return
	# Ordered queue: after a successful force, `_debug_sequence_slot` points at the next slot. Do not turn off
	# `event_debug_force` until those remaining slots are exhausted — otherwise the 2nd/3rd map event never forces.
	if main_node != null and _has_pending_non_none_sequence_slots(main_node):
		return
	debug_force_event = false
	debug_event_id = ""
	if main_had_force and main_node != null and "event_debug_force" in main_node:
		main_node.event_debug_force = false


## `Object.get()` only accepts one argument — use this for optional Main debug exports.
func _main_debug_seq_export(main_node: Node, key: String) -> String:
	var v: Variant = main_node.get(key)
	if v == null:
		return "__none__"
	var s := str(v)
	return s if not s.is_empty() else "__none__"


## Debug force + `event_debug_respect_prereqs`: only **`prereqs`** (tags, gold, resources, forbids, variables, …).
## Do **not** apply pool filters (`weight`, biome list, town vs wilderness, one_shot) — those exist so events like `debug_rewards_test` (weight 0) stay out of the random pool, not to block an explicit forced id.
func _forced_debug_event_respects_prereqs(ev: Dictionary, party_state: Dictionary) -> bool:
	if not ev.has("prereqs") or not ev.prereqs is Dictionary:
		return true
	var pr: Dictionary = ev.prereqs
	if pr.is_empty():
		return true
	return condition_passes(pr, party_state)


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
			# Merged separately via load_followup_events_from_json (trigger_tag → prereqs)
			if file_name.to_lower() == "followup_events.json":
				file_name = dir.get_next()
				continue
			var full_path = dir_path + "/" + file_name
			if load_events_from_json(full_path):
				loaded_count += 1
		file_name = dir.get_next()
	
	print("EventManager: Loaded %d event files from directory" % loaded_count)
	return loaded_count

## Load follow-up style events and merge into the main `events` pool (same weighted pick as everything else).
## trigger_tag becomes prereqs.requires_tags (merged with existing prereqs.requires_tags if present).
## Default weight 8 if omitted (slightly above generic world events) — tune per event in JSON.
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
		var e: Dictionary = event.duplicate(true)
		var tt: String = str(e.get("trigger_tag", ""))
		e.erase("trigger_tag")

		var prereqs: Dictionary = {}
		if e.has("prereqs") and e.prereqs is Dictionary:
			prereqs = e.prereqs.duplicate(true)
		var req_arr: Array = []
		if prereqs.has("requires_tags"):
			var rt: Variant = prereqs["requires_tags"]
			if rt is Array:
				req_arr = rt.duplicate()
		if not tt.is_empty() and not req_arr.has(tt):
			req_arr.append(tt)
		if not req_arr.is_empty():
			prereqs["requires_tags"] = req_arr
		if not prereqs.is_empty():
			e["prereqs"] = prereqs
		elif not tt.is_empty():
			e["prereqs"] = {"requires_tags": [tt]}

		if not e.has("weight"):
			e["weight"] = 8

		if events.has(e.id):
			push_warning("EventManager: follow-up merge overwrites existing event id '%s'" % e.id)
		events[e.id] = e
		loaded_count += 1
	
	print("EventManager: Merged %d follow-up events from %s into main pool" % [loaded_count, path])
	return true


## Quantity for party stash + gold: `gold` uses party gold; other ids use Main.party_resources (bulk items).
func _quantity_party_resource_id(item_id: String, party_state: Dictionary) -> int:
	var iid: String = item_id.strip_edges()
	if iid.is_empty():
		return 0
	if iid == "gold":
		var main_g: Node = _get_main_node()
		if main_g != null and "party_gold" in main_g:
			return int(main_g.party_gold)
		return int(party_state.get("party_gold", 0))
	var main: Node = _get_main_node()
	if main != null and main.has_method("get_party_resource_count"):
		return int(main.call("get_party_resource_count", iid))
	return int(party_state.get("party_resources", {}).get(iid, 0))


## Sum of item_id across character inventories only (ignores party_resources).
func _quantity_character_inventory_only(item_id: String) -> int:
	var main: Node = _get_main_node()
	if main == null or not ("run_roster" in main):
		return 0
	var total: int = 0
	for m in main.run_roster:
		if m is HeroCharacter:
			total += m.get_item_count(item_id)
	return total


## One JSON entry: { "id": "camping_supplies", "gte": 10 } — use any of eq, ne, lt, lte, gt, gte (can combine multiple predicates; all must pass).
func _quantity_check_entry_passes(actual: int, entry: Dictionary) -> bool:
	var found: bool = false
	var ok: bool = true
	if entry.has("eq"):
		found = true
		ok = ok and (actual == int(entry.eq))
	if entry.has("ne"):
		found = true
		ok = ok and (actual != int(entry.ne))
	if entry.has("lt"):
		found = true
		ok = ok and (actual < int(entry.lt))
	if entry.has("lte"):
		found = true
		ok = ok and (actual <= int(entry.lte))
	if entry.has("gt"):
		found = true
		ok = ok and (actual > int(entry.gt))
	if entry.has("gte"):
		found = true
		ok = ok and (actual >= int(entry.gte))
	if not found:
		push_warning("EventManager: quantity check for id '%s' needs at least one of eq, ne, lt, lte, gt, gte" % str(entry.get("id", "")))
		return false
	return ok


func _evaluate_quantity_condition_entries(entries: Variant, party_state: Dictionary, use_party_resources: bool) -> bool:
	if not entries is Array:
		return true
	if entries.is_empty():
		return true
	for raw in entries:
		if not raw is Dictionary:
			continue
		var e: Dictionary = raw
		var rid: String = str(e.get("id", "")).strip_edges()
		if rid.is_empty():
			push_warning("EventManager: party_resources / character_items entry missing 'id'")
			return false
		var qty: int = _quantity_party_resource_id(rid, party_state) if use_party_resources else _quantity_character_inventory_only(rid)
		if not _quantity_check_entry_passes(qty, e):
			return false
	return true


## Check if a condition passes given party state (from `_build_party_state`).
## Optional quantity gates (AND with everything else):
## • `party_resources`: [ { "id": "camping_supplies"|"gold"|bulk id, "gte": 10, ... } ] — stash + gold only.
## • `character_items`: [ { "id": "item_id", "eq": 2, ... } ] — sum across party members' inventories only.
## Comparators per entry: eq, ne, lt, lte, gt, gte (int). Multiple comparators on one entry = AND.
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

	# max_gold: party must not exceed this much gold
	if condition.has("max_gold"):
		if party.get("party_gold", 0) > condition.max_gold:
			return false

	# Party stash + gold quantities (not character inventory). id "gold" uses party_gold.
	if condition.has("party_resources"):
		if not _evaluate_quantity_condition_entries(condition.party_resources, party, true):
			return false

	# Character inventory totals only (equipment/consumables on members — ignores party_resources).
	if condition.has("character_items"):
		if not _evaluate_quantity_condition_entries(condition.character_items, party, false):
			return false

	return true


## True if arr has at least one required tag that is not a biome layer tag (biome:* is map/node, not contextual party tags).
func _has_non_biome_tag_requirement(arr: Variant) -> bool:
	if not arr is Array:
		return false
	for t in arr:
		var s: String = str(t).strip_edges().to_lower()
		if s.is_empty():
			continue
		if s.begins_with("biome:"):
			continue
		return true
	return false


## Positive tag requirements only (requires_tags / requires_any). Biome:* entries ignored here. forbids_tags not used.
func _tag_gate_dict_is_active(gate: Dictionary) -> bool:
	if _has_non_biome_tag_requirement(gate.get("requires_tags", [])):
		return true
	if _has_non_biome_tag_requirement(gate.get("requires_any", [])):
		return true
	return false


## True if `tag` appears in prereqs.requires_tags or prereqs.requires_any (exact string match).
func _prereqs_reference_tag(prereqs: Dictionary, tag: String) -> bool:
	var rt: Variant = prereqs.get("requires_tags", [])
	if rt is Array:
		for t in rt:
			if str(t) == tag:
				return true
	var ra: Variant = prereqs.get("requires_any", [])
	if ra is Array:
		for t in ra:
			if str(t) == tag:
				return true
	return false


## Biome list, town vs wilderness, one_shot consumption, positive weight.
func _event_passes_node_filters(ev: Dictionary, event_id: String, biome: String, is_town_node: bool) -> bool:
	if ev.get("one_shot", false) and event_id in seen_one_shot_events:
		return false
	if ev.has("biomes"):
		var event_biomes = ev.biomes
		if event_biomes is Array and event_biomes.size() > 0 and biome not in event_biomes:
			return false
	if is_town_node and not ev.get("town_entry", false):
		return false
	if not is_town_node and ev.get("town_entry", false):
		return false
	var w: float = float(ev.get("weight", 1))
	return w > 0.0


## Event is tag-driven if `prereqs` has at least one positive non-biome tag requirement (requires_tags / requires_any).
func _event_prereqs_are_tag_driven(prereqs: Dictionary) -> bool:
	return _tag_gate_dict_is_active(prereqs)


## True if prereqs use structured checks that are NOT tag-list gates (gold/resources/variables/forbids). Used for pool pass 2.
func _prereqs_have_structured_conditions(prereqs: Dictionary) -> bool:
	if prereqs.has("min_gold"):
		return true
	if prereqs.has("max_gold"):
		return true
	if prereqs.has("party_resources"):
		var pr: Variant = prereqs.party_resources
		if pr is Array and not pr.is_empty():
			return true
	if prereqs.has("character_items"):
		var ci: Variant = prereqs.character_items
		if ci is Array and not ci.is_empty():
			return true
	if prereqs.has("variables"):
		var v: Variant = prereqs.variables
		if v is Dictionary and not v.is_empty():
			return true
	if prereqs.has("forbids_tags"):
		var ft: Variant = prereqs.forbids_tags
		if ft is Array and not ft.is_empty():
			return true
	return false


## Build pool: (1) tag-keyed events matching a party tag + condition_passes; (2) events with only structured prereqs (gold/resources/etc., forbids) that pass condition_passes — no gold milestone tags required.
func _build_tag_driven_event_pool(biome: String, is_town_node: bool, party_state: Dictionary) -> Array:
	var pool: Array = []
	var seen_ids: Dictionary = {}
	var all_tags: Array[String] = TagManager.get_all_tags() if TagManager else []

	for party_tag in all_tags:
		var tag_str: String = str(party_tag)
		if tag_str.strip_edges().to_lower().begins_with("biome:"):
			continue
		for event_id in events.keys():
			if seen_ids.has(event_id):
				continue
			var ev: Dictionary = events[event_id]
			if not _event_passes_node_filters(ev, event_id, biome, is_town_node):
				continue
			if not ev.has("prereqs") or not ev.prereqs is Dictionary:
				continue
			var prereqs: Dictionary = ev.prereqs
			if not _event_prereqs_are_tag_driven(prereqs):
				continue
			if not _prereqs_reference_tag(prereqs, tag_str):
				continue
			if not condition_passes(prereqs, party_state):
				continue
			var weight: float = float(ev.get("weight", 1))
			seen_ids[event_id] = true
			pool.append({"event": ev, "weight": weight})

	# Numeric / resource / forbids-only prereqs (no requires_tags/requires_any) — evaluated when gold or stash changes via condition_passes at pick time.
	for event_id in events.keys():
		if seen_ids.has(event_id):
			continue
		var ev2: Dictionary = events[event_id]
		if not _event_passes_node_filters(ev2, event_id, biome, is_town_node):
			continue
		if not ev2.has("prereqs") or not ev2.prereqs is Dictionary:
			continue
		var prereqs2: Dictionary = ev2.prereqs
		if _event_prereqs_are_tag_driven(prereqs2):
			continue
		if not _prereqs_have_structured_conditions(prereqs2):
			continue
		if not condition_passes(prereqs2, party_state):
			continue
		var w2: float = float(ev2.get("weight", 1))
		seen_ids[event_id] = true
		pool.append({"event": ev2, "weight": w2})

	return pool


func _weighted_random_from_event_pool(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_weight: float = 0.0
	for item in pool:
		total_weight += item.weight
	var roll: float = rng.randf_range(0.0, total_weight)
	var acc: float = 0.0
	for item in pool:
		acc += item.weight
		if roll <= acc:
			return item.event
	return pool[0].event


const TAG_DRIVEN_FALLBACK_EVENT_ID := "__tag_driven_pool_empty__"


func _make_tag_driven_fallback_event() -> Dictionary:
	return {
		"id": TAG_DRIVEN_FALLBACK_EVENT_ID,
		"title": "SYSTEM: Event pool empty",
		"biomes": [],
		"weight": 0,
		"one_shot": false,
		"text": "No tag-driven event matched this node. The tag_driven_event_pool was empty after filtering (add event.prereqs with requires_tags / requires_any, or structured gates: min_gold, max_gold, party_resources [{id,gte,...}], character_items, forbids_tags. Gold uses prereqs — not tags.)",
		"choices": [
			{
				"id": "acknowledge",
				"text": "Continue",
				"effects": [],
				"next_event": null,
				"weight": 1
			}
		]
	}


func _snapshot_last_pick(biome: String, is_town: bool, forced: bool, selected_id: String, pool_size: int, total_w: float, roll: float) -> void:
	debug_last_pick_biome = biome
	debug_last_pick_is_town = is_town
	debug_last_pick_was_forced = forced
	debug_last_pick_selected_id = selected_id
	debug_last_pick_rolled_pool_size = pool_size
	debug_last_pick_total_weight = total_w
	debug_last_pick_roll = roll


## Universal entry: refresh tags, optional debug force (one-shot or sticky), then eligibility pool (tags + structured prereqs), weighted pick, else fallback error event.
func pick_event_for_node(biome: String, party: Dictionary, node_state: Dictionary = {}) -> Dictionary:
	if events.is_empty():
		push_warning("%sno events loaded, cannot pick" % EVENT_SELECTION_LOG_PREFIX)
		_snapshot_last_pick(biome, node_state.get("is_town", false), false, "", 0, 0.0, -1.0)
		debug_last_pick_eligible_count = 0
		return {}

	var main_node: Node = _get_main_node()
	if TagManager:
		if main_node:
			TagManager.refresh_tags(main_node, main_node.run_roster, int(party.get("party_gold", 0)), biome)
		else:
			TagManager.refresh_tags(null, [], int(party.get("party_gold", 0)), biome)

	var party_state_dict: Dictionary = _build_party_state(party)
	var is_town_node: bool = node_state.get("is_town", false)

	var force_event: bool = debug_force_event
	var force_id: String = debug_event_id
	var main_wants_force: bool = main_node != null and "event_debug_force" in main_node and main_node.event_debug_force
	if not main_wants_force:
		_debug_sequence_slot = 0
	if main_node and main_wants_force:
		force_event = true
		force_id = ""
		# Ordered sequence (optional): event_debug_id_1 → _2 → _3, skipping __none__ without burning a map pick.
		var seq_slots: Array = [
			_main_debug_seq_export(main_node, "event_debug_id_1"),
			_main_debug_seq_export(main_node, "event_debug_id_2"),
			_main_debug_seq_export(main_node, "event_debug_id_3"),
		]
		while _debug_sequence_slot < 3:
			var cand: String = seq_slots[_debug_sequence_slot]
			_debug_sequence_slot += 1
			if cand != "__none__" and not cand.is_empty():
				force_id = cand
				break
		if force_id.is_empty():
			force_id = str(main_node.event_debug_id)
			if force_id == "__none__":
				force_id = ""

	if force_event and not force_id.is_empty():
		if events.has(force_id):
			var ev_force: Dictionary = events[force_id]
			var respect_prereqs: bool = true
			if main_node != null:
				var rp: Variant = main_node.get("event_debug_respect_prereqs")
				if rp != null:
					respect_prereqs = bool(rp)
			if respect_prereqs and not _forced_debug_event_respects_prereqs(ev_force, party_state_dict):
				push_warning("%sdebug force skipped '%s' — event `prereqs` not met (tags / gold / resources / forbids); set Main.event_debug_respect_prereqs = false to force anyway" % [EVENT_SELECTION_LOG_PREFIX, force_id])
				_event_pick_log(main_node, "forced skip id=%s (prereqs)" % force_id)
				# Do not rewind `_debug_sequence_slot`: the while-loop already advanced past this id. Rewinding
				# would retry id_1 forever and never reach `event_debug_id_2` / `_3` on later map picks.
				force_event = false
			else:
				print("%sforced debug event '%s' (clear after pick unless event_debug_keep_forcing)" % [EVENT_SELECTION_LOG_PREFIX, force_id])
				_event_pick_log(main_node, "forced id=%s (pool skipped)" % force_id)
				_snapshot_last_pick(biome, is_town_node, true, force_id, -1, 0.0, -1.0)
				debug_last_pick_eligible_count = -1
				_clear_debug_event_force_after_pick(main_node, main_wants_force)
				return ev_force
		else:
			push_warning("%sdebug event id '%s' not found" % [EVENT_SELECTION_LOG_PREFIX, force_id])
	elif force_event and force_id.is_empty():
		push_warning("%sdebug force on but no event_debug_id set" % EVENT_SELECTION_LOG_PREFIX)

	var tag_pool: Array = _build_tag_driven_event_pool(biome, is_town_node, party_state_dict)
	debug_last_pick_eligible_count = tag_pool.size()

	if tag_pool.is_empty():
		push_warning("%stag_driven_event_pool empty (biome='%s', town=%s) — showing fallback event" % [EVENT_SELECTION_LOG_PREFIX, biome, str(is_town_node)])
		var fb: Dictionary = _make_tag_driven_fallback_event()
		_snapshot_last_pick(biome, is_town_node, false, TAG_DRIVEN_FALLBACK_EVENT_ID, 0, 0.0, -1.0)
		_event_pick_log(main_node, "biome=%s tag_driven_pool=0 → FALLBACK '%s'" % [biome, TAG_DRIVEN_FALLBACK_EVENT_ID])
		return fb

	var total_weight: float = 0.0
	for it in tag_pool:
		total_weight += it.weight
	var roll: float = rng.randf_range(0.0, total_weight)
	var chosen: Dictionary = _weighted_random_from_event_pool(tag_pool)
	var chosen_id: String = str(chosen.get("id", ""))
	if chosen.get("one_shot", false):
		seen_one_shot_events.append(chosen_id)

	_snapshot_last_pick(biome, is_town_node, false, chosen_id, tag_pool.size(), total_weight, roll)
	_event_pick_log(main_node, "biome=%s chose '%s' | tag_driven_pool=%d tags total_weight=%.1f roll=%.3f" % [biome, chosen_id, tag_pool.size(), total_weight, roll])
	return chosen

## Present an event - returns event with filtered choices.
## If **`immediate_effects`** (array) is set on the event, those effects run here as soon as the event is presented (before the log UI), not when a choice is picked.
func present_event(event: Dictionary, party: Dictionary, node_state: Dictionary = {}) -> Dictionary:
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
	
	var immediate: Variant = presented_event.get("immediate_effects", [])
	if immediate is Array and not immediate.is_empty():
		apply_effects(immediate as Array, party, node_state)
	
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


func effect_timing(effect: Dictionary) -> String:
	var t: String = str(effect.get("timing", EFFECT_TIMING_AFTER_TEXT)).strip_edges()
	if t == EFFECT_TIMING_BEFORE_TEXT or t == EFFECT_TIMING_ON_EVENT_CLOSE:
		return t
	return EFFECT_TIMING_AFTER_TEXT


## Split effect list by `timing`. `on_event_close` effects are not returned here — queue them with **`ingest_effects_split_for_nested`** or **`apply_effects`**.
func split_effects_by_timing(effects: Array) -> Dictionary:
	var before: Array = []
	var after: Array = []
	var close: Array = []
	if effects is Array:
		for raw in effects:
			if not raw is Dictionary:
				continue
			var e: Dictionary = normalize_effect_for_apply(raw)
			match effect_timing(e):
				EFFECT_TIMING_BEFORE_TEXT:
					before.append(e)
				EFFECT_TIMING_ON_EVENT_CLOSE:
					close.append(e)
				_:
					after.append(e)
	return {"before": before, "after": after, "close": close}


## Queues `on_event_close` effects and returns **`before`** and **`after`** arrays for phased application (nested steps).
func ingest_effects_split_for_nested(effects: Array) -> Dictionary:
	var s: Dictionary = split_effects_by_timing(effects)
	for e in s.close:
		pending_effects_on_event_close.append(e)
	return {"before": s.before, "after": s.after}


## Run queued **`on_event_close`** effects (no further splitting — avoids re-queue loops).
func drain_effects_on_event_close(party: Dictionary, node_state: Dictionary) -> void:
	if pending_effects_on_event_close.is_empty():
		return
	var batch: Array = pending_effects_on_event_close.duplicate()
	pending_effects_on_event_close.clear()
	apply_effects_array(batch, party, node_state)


## Pick a weighted **`weighted_branches`** entry: `[{ "weight": n, "step": { ... } }, ...]`. One branch → that step only; no roll.
func pick_weighted_branches(branches: Array) -> Dictionary:
	if branches.is_empty():
		return {}
	if branches.size() == 1:
		var only: Variant = branches[0]
		if only is Dictionary:
			return only.get("step", {}) as Dictionary
		return {}
	var total_weight: float = 0.0
	for br in branches:
		if br is Dictionary:
			total_weight += float(br.get("weight", 1))
	if total_weight <= 0.0:
		var fb0: Variant = branches[0]
		if fb0 is Dictionary:
			return fb0.get("step", {}) as Dictionary
		return {}
	var roll: float = rng.randf_range(0.0, total_weight)
	var acc: float = 0.0
	for br in branches:
		if br is Dictionary:
			acc += float(br.get("weight", 1))
			if roll <= acc:
				return br.get("step", {}) as Dictionary
	var last: Variant = branches[branches.size() - 1]
	if last is Dictionary:
		return last.get("step", {}) as Dictionary
	return {}


## Apply effects from a choice (legacy + timing). **`on_event_close`** effects queue; **`before_text`** then **`after_text`** run in order.
func apply_effects(effects: Array, party: Dictionary, node_state: Dictionary = {}):
	text_vars.clear()
	if stat_check_context.has("actor_name"):
		text_vars["actor"] = stat_check_context["actor_name"]
	if stat_check_context.has("tier"):
		text_vars["tier"] = stat_check_context["tier"]
	debug_print("SECRET PATH: EventManager apply_effects() called with %d effects" % effects.size())

	if not effects is Array:
		debug_print("SECRET PATH: Effects is not an array!")
		stat_check_context.clear()
		return

	var s: Dictionary = split_effects_by_timing(effects)
	for e in s.close:
		pending_effects_on_event_close.append(e)
	apply_effects_array(s.before + s.after, party, node_state)
	stat_check_context.clear()


## Apply normalized effect dicts in order (no timing split — used by **`drain_effects_on_event_close`** and direct step runs).
func apply_effects_array(effects: Array, party: Dictionary, node_state: Dictionary = {}) -> void:
	if not effects is Array:
		return
	for raw in effects:
		if not raw is Dictionary:
			push_warning("SECRET PATH: EventManager Effect is not a dictionary, skipping")
			continue
		var effect: Dictionary = normalize_effect_for_apply(raw)
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
				pass # Legacy JSON — no reputation system; ignored silently

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

			"give_item_choice":
				_apply_give_item_choice(effect, party)

			"give_trait":
				_apply_give_trait(effect, party)

			"give_xp":
				_apply_give_xp(effect, party)

			"heal_party":
				_apply_heal_party(effect, party)

			"recruit_hero":
				_apply_recruit_hero(effect, party)

			"unlock_hero_meta":
				_apply_unlock_hero_meta(effect, party)

			"set_weather":
				_apply_set_weather(effect)

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
	
	# Variables (if party dict has it)
	if party.has("variables"):
		state.variables = party.variables
	else:
		state.variables = {}

	# Party gold (for conditions like min_gold)
	state.party_gold = party.get("party_gold", 0)

	# Copy of party_resources for fallbacks when Main is unavailable (e.g. tests)
	if party.has("party_resources") and party.party_resources is Dictionary:
		state.party_resources = party.party_resources.duplicate(true)
	else:
		state.party_resources = {}
	
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

## Optional JSON keys that map to canonical fields (shallow copy; originals unchanged).
## Keeps older snippets and copy-paste mistakes working without forking effect types.
func normalize_effect_for_apply(effect: Dictionary) -> Dictionary:
	var e: Dictionary = effect.duplicate()
	var t: String = str(e.get("type", ""))
	match t:
		"give_item", "consume_item":
			if not e.has("item_id") and e.has("item"):
				e["item_id"] = str(e["item"])
			if not e.has("count") and not (e.has("min_count") and e.has("max_count")):
				if e.has("amount"):
					e["count"] = int(e["amount"])
		"script_hook":
			if not e.has("hook_name") and e.has("hook_id"):
				e["hook_name"] = str(e["hook_id"])
	return e


func normalize_effects_array(effects: Array) -> Array:
	var out: Array = []
	for raw in effects:
		if raw is Dictionary:
			out.append(normalize_effect_for_apply(raw))
		else:
			out.append(raw)
	return out


## Resolves `tag` (string), `tag` (array of strings), or `tags` (array). If `tags` is present, it wins over `tag`.
func _coerce_effect_tag_list(effect: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if effect.has("tags"):
		var raw: Variant = effect.get("tags")
		if raw is Array:
			for it in raw:
				var s: String = str(it).strip_edges()
				if not s.is_empty():
					out.append(s)
		return out
	if effect.has("tag"):
		var tv: Variant = effect.get("tag")
		if tv is Array:
			for it in tv:
				var s2: String = str(it).strip_edges()
				if not s2.is_empty():
					out.append(s2)
		else:
			var s3: String = str(tv).strip_edges()
			if not s3.is_empty():
				out.append(s3)
	return out


func _apply_add_tag(effect: Dictionary, party: Dictionary):
	if not TagManager:
		push_warning("EventManager: TagManager not available for add_tag effect")
		return
	var tag_list: Array[String] = _coerce_effect_tag_list(effect)
	if tag_list.is_empty():
		push_warning("EventManager: add_tag effect needs non-empty 'tag', 'tag' array, or 'tags' array")
		return
	for t in tag_list:
		TagManager.add_tag(t)


func _apply_remove_tag(effect: Dictionary, party: Dictionary):
	if not TagManager:
		push_warning("EventManager: TagManager not available for remove_tag effect")
		return
	var tag_list: Array[String] = _coerce_effect_tag_list(effect)
	if tag_list.is_empty():
		push_warning("EventManager: remove_tag effect needs non-empty 'tag', 'tag' array, or 'tags' array")
		return
	for t in tag_list:
		TagManager.remove_tag(t)

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
	if main.run_roster.is_empty():
		push_warning("EventManager: give_item requires party members for non-resource items")
		return
	pending_event_log_visual_queue.append({
		"kind": "item",
		"reward": { "item_id": effect.item_id, "count": count, "item": item },
	})


func _queue_event_log_visual_reward_row(xp: int, gold: int) -> void:
	if xp <= 0 and gold <= 0:
		return
	pending_event_log_visual_queue.append({ "kind": "rewards", "xp": xp, "gold": gold })


## Drains ordered EventLog visuals (EventRewards rows, ItemReward, ItemChoiceReward). Clears the queue.
func drain_pending_event_log_visual_queue() -> Array:
	var drained := pending_event_log_visual_queue.duplicate()
	pending_event_log_visual_queue.clear()
	return drained

## give_trait effect handler — traits are never assigned via a member-picker UI (unlike items).
## Who receives the trait comes from the event data + the choice the player picked:
##
##   member_name  — grant to the first alive party member whose member_name matches (case-insensitive).
##                  Use when each narrative choice names a specific character.
##   target       — "all" | "random" | party slot index (0 = first member in Main.run_roster).
##                  JSON numbers may arrive as float; whole-number floats are accepted.
##
## Outcome text can use {member} after a single-recipient grant (random, slot, or member_name).
## Deprecated: target "acted" (old member-picker) — logs a warning and behaves like "random".
func _apply_give_trait(effect: Dictionary, party: Dictionary) -> void:
	var trait_id: String = str(effect.get("trait_id", ""))
	# Main._build_party_dict() does NOT set party["alive"] — must resolve HeroCharacter refs from Main
	# (same as give_xp / heal_party). Using party.get("alive", []) alone always failed silently.
	var alive: Array = _get_alive_party_members()
	if alive.is_empty():
		push_warning("EventManager: give_trait — no alive party members (Main missing or party empty)")
		return

	var members: Array = _resolve_give_trait_recipients(effect, alive)

	if members.is_empty():
		return

	# Set text_vars before any database validation so {member} always substitutes correctly.
	if members.size() == 1:
		text_vars["member"] = members[0].member_name

	if trait_id.is_empty() or not TraitDatabase.has_trait(trait_id):
		push_warning("EventManager: give_trait unknown or missing trait_id '%s'" % trait_id)
		return

	for member in members:
		member.add_trait(trait_id)
		print("EventManager: %s gained trait '%s'" % [member.member_name, trait_id])

func _resolve_give_trait_recipients(effect: Dictionary, alive: Array) -> Array:
	var member_name: String = str(effect.get("member_name", "")).strip_edges()
	if not member_name.is_empty():
		for m in alive:
			if m.member_name.to_lower() == member_name.to_lower():
				return [m]
		push_warning("EventManager: give_trait member_name '%s' not found among alive party" % member_name)
		return []

	var target = effect.get("target", "random")
	if str(target) == "acted":
		push_warning("EventManager: give_trait target \"acted\" was removed — use \"member_name\" or slot index 0,1,… (or separate choices). Using random.")
		target = "random"

	return _resolve_member_targets(target, alive)

## Resolve count from an effect/item entry supporting count, min_count, max_count, or amount (alias for count).
func _resolve_item_count(entry: Dictionary) -> int:
	if entry.has("min_count") and entry.has("max_count"):
		return rng.randi_range(int(entry.min_count), int(entry.max_count))
	if entry.has("count"):
		return int(entry["count"])
	if entry.has("amount"):
		return int(entry["amount"])
	return 1

## Fisher-Yates shuffle using the seeded RNG; returns a new array.
func _shuffle_array(arr: Array) -> Array:
	var result := arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result

## give_item_choice effect handler.
## grant:"all"  → every resolved item goes through _apply_give_item (or party resources if bulk).
## grant:"one"  → one pending_event_log_visual_queue entry; EventLog shows ItemChoiceReward.
##
## Sources:
##   pool + pool_draw  — draw pool_draw distinct items from pool (default 1)
##   items             — explicit list of {item_id [, count|min_count|max_count]} entries
func _apply_give_item_choice(effect: Dictionary, party: Dictionary) -> void:
	var grant: String = effect.get("grant", "all")

	# Build resolved candidate list: [{item_id, count}]
	var candidates: Array = []
	if effect.has("pool"):
		var pool: Array = effect.get("pool", [])
		var draw: int = int(effect.get("pool_draw", 1))
		var drawn: Array = _shuffle_array(pool).slice(0, mini(draw, pool.size()))
		for item_id in drawn:
			candidates.append({ "item_id": str(item_id), "count": _resolve_item_count(effect) })
	else:
		for entry in effect.get("items", []):
			if entry is Dictionary:
				var row: Dictionary = entry.duplicate()
				row["type"] = "give_item"
				row = normalize_effect_for_apply(row)
				var iid: String = str(row.get("item_id", ""))
				candidates.append({ "item_id": iid, "count": _resolve_item_count(row) })

	if candidates.is_empty():
		push_warning("EventManager: give_item_choice has no items or pool")
		return

	if grant == "all":
		for c in candidates:
			_apply_give_item({ "item_id": c.item_id, "count": c.count }, party)
	else:
		# "one" — collect Item resources and queue as a choice set
		var valid_items: Array = []
		for c in candidates:
			if not ItemDatabase.has_item(c.item_id):
				push_warning("EventManager: give_item_choice unknown item_id '%s'" % c.item_id)
				continue
			valid_items.append({
				"item_id": c.item_id,
				"count":   c.count,
				"item":    ItemDatabase.get_item(c.item_id)
			})
		if not valid_items.is_empty():
			pending_event_log_visual_queue.append({ "kind": "item_choice", "items": valid_items })

## Actually grants a character item to the chosen member after the player picks via ItemReward UI.
func fulfill_item_reward(item_id: String, count: int, member: HeroCharacter) -> void:
	if not ItemDatabase.has_item(item_id):
		push_warning("EventManager: fulfill_item_reward unknown item_id '%s'" % item_id)
		return
	var item := ItemDatabase.get_item(item_id)
	var main: Node = _get_main_node()
	var party_total: int = 0
	if main:
		for m in main.run_roster:
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

func _apply_change_stat(effect: Dictionary, party: Dictionary):
	if not effect.has("stat") or not effect.has("amount"):
		push_warning("EventManager: change_stat effect missing 'stat' or 'amount' field")
		return

	var stat_id: String = str(effect.stat)
	var amount: int = int(effect.amount)
	var target: Variant = effect.get("target", "party")
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: change_stat requires Main")
		return

	if stat_id == "hp":
		var alive: Array = main.run_roster.filter(func(m): return m.is_alive())
		if alive.is_empty():
			return
		var targets: Array = alive
		if target == "party" or target == "all":
			targets = alive
		else:
			targets = _resolve_member_targets(target, alive)
		for member in targets:
			if amount < 0:
				member.take_damage(-amount)
			else:
				member.heal(amount)
			print("EventManager: change_stat hp %+d → %s (%d/%d)" % [amount, member.member_name, member.current_health, member.max_health])
		return

	if stat_id == "gold":
		if "party_gold" in main:
			main.party_gold = max(0, int(main.party_gold) + amount)
			if main.ui_controller and main.ui_controller.map_ui and main.ui_controller.map_ui.has_method("update_resource_labels"):
				main.ui_controller.map_ui.update_resource_labels(main.run_roster, main.party_gold, main.party_resources)
		return

	push_warning("EventManager: change_stat unsupported stat '%s'" % stat_id)

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
	
	print("EventManager: Starting combat with %d party members" % main.run_roster.size())
	
	# Start combat via CombatController
	CombatController.start_combat_from_encounter(encounter, main.run_roster)

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
	if main.ui_controller and main.ui_controller.map_ui and main.ui_controller.map_ui.has_method("update_resource_labels"):
		main.ui_controller.map_ui.update_resource_labels(main.run_roster, main.party_gold, main.party_resources)

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
	if main.ui_controller and main.ui_controller.map_ui and main.ui_controller.map_ui.has_method("update_resource_labels"):
		main.ui_controller.map_ui.update_resource_labels(main.run_roster, main.party_gold, main.party_resources)
	_queue_event_log_visual_reward_row(0, amount)

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
	if item_id == "gold" and "party_gold" in main:
		return int(main.party_gold) >= count
	if ItemDatabase.is_bulk_loot(item_id):
		return main.get_party_resource_count(item_id) >= count
	# Non-bulk: sum across all party members
	var total := 0
	for m in main.run_roster:
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
		for m in main.run_roster:
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
	var alive: Array = main.run_roster.filter(func(m): return m.is_alive())
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
	# EventRewards row: total XP granted this effect (EventLog); skip force_level_up (no +XP line).
	if not force_level_up and amount > 0:
		_queue_event_log_visual_reward_row(amount * targets.size(), 0)

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
	var alive: Array = main.run_roster.filter(func(m): return m.is_alive())
	if alive.is_empty():
		return
	var target = effect.get("target", "all")
	var targets: Array = _resolve_member_targets(target, alive)
	for member in targets:
		var healed: int = 0
		if effect.has("percent"):
			healed = int(member.max_health * float(effect.percent) / 100.0)
			member.heal(healed)
		elif str(effect.get("amount", "")) == "full":
			healed = member.max_health - member.current_health
			member.heal(member.max_health)
		else:
			healed = int(effect.get("amount", 0))
			member.heal(healed)
		print("EventManager: Healed %s for %d HP (%d/%d)" % [member.member_name, healed, member.current_health, member.max_health])

## Resolve a target field into an Array of HeroCharacter references from the alive pool.
## target: "all" → all alive members | "random" → one random alive member | int/float → slot in Main.run_roster
func _resolve_member_targets(target, alive: Array) -> Array:
	# JSON numbers are often float; never compare float to String (runtime error in GDScript 4).
	if typeof(target) == TYPE_STRING:
		if target == "all":
			return alive
		if target == "random":
			return [alive[rng.randi() % alive.size()]]
		if target == "stat_actor" or target == "actor":
			var main_sa: Node = _get_main_node()
			if main_sa and stat_check_context.has("actor_index"):
				var ai: int = int(stat_check_context["actor_index"])
				if ai >= 0 and ai < main_sa.run_roster.size():
					var m_sa: HeroCharacter = main_sa.run_roster[ai]
					if m_sa.is_alive():
						return [m_sa]
			push_warning("EventManager: stat_actor target but no valid stat_check_context — using random")
			return [alive[rng.randi() % alive.size()]]
	var main: Node = _get_main_node()
	if not main:
		push_warning("EventManager: _resolve_member_targets: no Main node, defaulting to random")
		return [alive[rng.randi() % alive.size()]]

	var idx: int = -1
	if typeof(target) == TYPE_INT:
		idx = target
	elif typeof(target) == TYPE_FLOAT:
		var f: float = target
		if is_equal_approx(f, roundf(f)):
			idx = int(f)
	elif typeof(target) == TYPE_STRING:
		var s: String = str(target)
		if s.is_valid_int():
			idx = int(s)

	if idx >= 0 and idx < main.run_roster.size():
		var m = main.run_roster[idx]
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


## After weather changes mid-event, rebuild derived tags so `weather:*` prereqs match until the next node move (which re-rolls weather).
func _sync_tag_manager_after_weather_change() -> void:
	if not TagManager:
		return
	var main: Node = _get_main_node()
	if main == null:
		return
	var biome_name: String = ""
	if "map_generator" in main and main.map_generator:
		var mg: Variant = main.map_generator
		if mg.current_party_node and mg.current_party_node.biome:
			biome_name = str(mg.current_party_node.biome.biome_name)
	var members: Array = main.run_roster if "run_roster" in main else []
	var gold: int = int(main.party_gold) if "party_gold" in main else 0
	TagManager.refresh_tags(main, members, gold, biome_name)


## JSON: `{ "type": "recruit_hero", "template_path": "..." }` or `"hero_id": "starter_elf_wizard"`.
## Optional: `"join_party": false` — skip adding to `run_roster` (story-only path). Optional: `"meta_unlock": true` — persist unlock for party select on **future** runs (only for ids in `HeroDatabase.meta_unlockable_template_paths()`).
func _apply_recruit_hero(effect: Dictionary, party: Dictionary) -> void:
	var join_party: bool = bool(effect.get("join_party", true))
	var meta_unlock: bool = bool(effect.get("meta_unlock", false))
	var path: String = str(effect.get("template_path", "")).strip_edges()
	var hid_eff: String = str(effect.get("hero_id", "")).strip_edges()
	if path.is_empty() and not hid_eff.is_empty():
		path = HeroDatabase.template_path_for_hero_id(hid_eff)
	var resolved_id: String = hid_eff
	if resolved_id.is_empty() and not path.is_empty():
		var tpl_resolve: HeroCharacter = HeroDatabase.load_template(path)
		if tpl_resolve:
			resolved_id = tpl_resolve.hero_id
	if meta_unlock and not resolved_id.is_empty():
		if HeroDatabase.is_meta_unlockable_hero_id(resolved_id):
			MetaProgression.unlock_hero(resolved_id)
		else:
			push_warning("EventManager: recruit_hero meta_unlock ignored — '%s' is not a registered meta-unlock hero_id" % resolved_id)
	if not join_party:
		if not meta_unlock:
			push_warning("EventManager: recruit_hero join_party false but meta_unlock false — no effect")
		return
	if path.is_empty():
		push_warning("EventManager: recruit_hero needs non-empty template_path or hero_id")
		return
	var main: Node = _get_main_node()
	if main == null or not main.has_method("recruit_hero_from_template"):
		push_warning("EventManager: recruit_hero requires Main")
		return
	var ok: bool = bool(main.call("recruit_hero_from_template", path))
	if ok and "run_roster" in main:
		var rr: Array = main.run_roster
		if rr.size() > 0:
			var last: Variant = rr[rr.size() - 1]
			if last is HeroCharacter:
				var h: HeroCharacter = last as HeroCharacter
				text_vars["recruited_name"] = h.member_name if not h.member_name.is_empty() else h.hero_id
	print("EventManager: recruit_hero → %s (ok=%s)" % [path, ok])


## JSON: `{ "type": "unlock_hero_meta", "hero_id": "unlockable_sellsword" }` — cross-run unlock only (no party add). Prefer `recruit_hero` with `meta_unlock` when you also want them in the roster.
func _apply_unlock_hero_meta(effect: Dictionary, party: Dictionary) -> void:
	var hid: String = str(effect.get("hero_id", "")).strip_edges()
	if hid.is_empty():
		push_warning("EventManager: unlock_hero_meta needs hero_id")
		return
	if not HeroDatabase.is_meta_unlockable_hero_id(hid):
		push_warning("EventManager: unlock_hero_meta — unknown meta-unlock hero_id '%s'" % hid)
		return
	MetaProgression.unlock_hero(hid)


## JSON: `{ "type": "set_weather", "weather_id": "rainy" }` — must match an id in `data/weather/weather_types.json`.
func _apply_set_weather(effect: Dictionary) -> void:
	var wid: String = str(effect.get("weather_id", "")).strip_edges()
	if wid.is_empty():
		push_warning("EventManager: set_weather effect missing weather_id")
		return
	var root: Window = get_tree().root if get_tree() else null
	var wm: Node = root.get_node_or_null("WeatherManager") if root else null
	if wm == null or not wm.has_method("set_weather"):
		push_warning("EventManager: WeatherManager missing or has no set_weather")
		return
	wm.call("set_weather", wid)
	_sync_tag_manager_after_weather_change()

## Alive HeroCharacter instances for effects that target party members by index / random / name.
## Do not use party_dict["members"] — those are plain dictionaries for text interpolation.
func _get_alive_party_members() -> Array:
	var main: Node = _get_main_node()
	if not main:
		return []
	return main.run_roster.filter(func(m): return m.is_alive())

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
