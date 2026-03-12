extends Control

## Main game manager - handles overall game state, menus, and coordination
## Central script for game-wide logic
## UI elements live under UIController (CanvasLayer); Main accesses via ui_controller

@onready var map_generator: MapGenerator2D = $MapGenerator
@onready var ui_controller: CanvasLayer = $UIController

# Game state
enum GameState {
	MAIN_MENU,
	PARTY_SELECT,
	IN_GAME
}

## Holds the post-combat outcome block for the current fight. Set in _on_combat_ended,
## consumed in on_combat_scene_fully_ended, then cleared.
var _pending_combat_outcome: Dictionary = {}

var current_state: GameState = GameState.MAIN_MENU
var game_started: bool = false
var current_world_name: String = ""
var current_party_members: Array[PartyMember] = []
var party_gold: int = 150  # Starting gold (for debugging)
## Party-wide resources (item_id -> count). Bulk items: health_potion, camping_supplies, sharpening_stone, magical_dust.
## Not tied to any character; don't occupy item slots.
var party_resources: Dictionary = {}
var party_has_traveled: bool = false  # Track if party has actually traveled (not just initial spawn)
var _town_node_for_rest: MapNode2D = null  # When in town, Inn rest returns here instead of map
var _vendor_opened_from_town: bool = false
var _blacksmith_opened_from_town: bool = false
var _town_node_indices_granted_entry: Array[int] = []  # Node indices of towns player has been granted entry to
var _in_potion_target_mode: bool = false  # True when awaiting character click to apply health potion

## Event debug: when true, EventManager forces this event ID on the next node (e.g. "test_warg_ambush_outcomes"). Editable in Main scene inspector.
@export var event_debug_force: bool = false
@export var event_debug_id: String = ""
## When true, EventManager prints detailed event selection logs (follow-up checks, rolls, normal pool). Set in Main scene inspector.
@export var debug_event_selection: bool = false

func _ready():
	add_to_group("main")
	# Connect menu signals automatically
	_connect_menu_signals()
	
	# Initialize menu visibility
	show_menu(GameState.MAIN_MENU)
	
	# Hide map generator until game starts
	map_generator.visible = false
	map_generator.map_generation_complete.connect(_on_map_generation_complete)
	map_generator.party_moved_to_node.connect(_on_party_moved_to_node)
	map_generator.travel_started.connect(_on_travel_started)
	map_generator.travel_completed.connect(_on_travel_completed)
	
	# MapUI emits rest_requested, town_requested, health_potion_use_requested
	ui_controller.map_ui.rest_requested.connect(_on_rest_requested)
	ui_controller.map_ui.town_requested.connect(_on_town_requested)
	ui_controller.map_ui.health_potion_use_requested.connect(_on_health_potion_use_requested)
	ui_controller.potion_target_selected.connect(_on_potion_target_selected)
	
	# Hide and connect rest controller
	ui_controller.rest_controller.visible = false
	ui_controller.rest_controller.rest_complete.connect(_on_rest_complete)
	ui_controller.rest_controller.ambush_triggered.connect(_on_rest_ambush_triggered)
	
	# Connect event log signal to update rest button when event closes
	ui_controller.event_log.event_closed.connect(_on_event_closed)

	ui_controller.town_screen.town_closed.connect(_on_town_screen_closed)
	ui_controller.town_screen.rest_from_town_requested.connect(_on_rest_from_town_requested)
	ui_controller.town_screen.warmaster_training_requested.connect(_on_warmaster_training_requested)
	ui_controller.town_screen.vendor_requested.connect(_on_vendor_requested)
	ui_controller.town_screen.blacksmith_requested.connect(_on_blacksmith_requested)
	ui_controller.vendor_screen.vendor_closed.connect(_on_vendor_closed)
	ui_controller.vendor_screen.party_gold_changed.connect(_on_vendor_gold_changed)
	ui_controller.blacksmith_screen.blacksmith_closed.connect(_on_blacksmith_closed)
	ui_controller.blacksmith_screen.party_gold_changed.connect(_on_blacksmith_gold_changed)
	
	CombatController.combat_ended.connect(_on_combat_ended)

## Automatically connect all menu signals
func _connect_menu_signals():
	ui_controller.main_menu.start_game_pressed.connect(_on_main_menu_start_pressed)
	ui_controller.main_menu.quit_pressed.connect(_on_main_menu_quit_pressed)
	
	ui_controller.party_select_menu.start_game_pressed.connect(_on_party_select_start_pressed)
	ui_controller.party_select_menu.back_to_main_menu_pressed.connect(_on_party_select_back_pressed)

## Show a specific menu and hide others
func show_menu(state: GameState):
	current_state = state
	
	# Hide all menus and map UI
	ui_controller.main_menu.visible = false
	ui_controller.party_select_menu.visible = false
	map_generator.visible = false
	ui_controller.map_ui.visible = false
	
	# Show the appropriate menu
	match state:
		GameState.MAIN_MENU:
			ui_controller.main_menu.visible = true
		GameState.PARTY_SELECT:
			ui_controller.party_select_menu.visible = true
		GameState.IN_GAME:
			map_generator.visible = true
			ui_controller.map_ui.visible = true

## Signal handlers for MainMenu
func _on_main_menu_start_pressed():
	show_menu(GameState.PARTY_SELECT)

func _on_main_menu_quit_pressed():
	get_tree().quit()

## Signal handlers for PartySelectMenu
func _on_party_select_start_pressed(party_members: Array[PartyMember], world_name: String):
	# Update TagManager with party composition
	if TagManager:
		TagManager.update_tags_from_party(party_members)
	
	# Store party data and world name
	current_party_members = party_members
	current_world_name = world_name
	print("World Name: ", world_name)
	
	# Update map generator with world name
	map_generator.set_world_name(world_name)
	
	# Show map generator (will be hidden until map is generated)
	show_menu(GameState.IN_GAME)
	
	# Start map generation now that party is selected
	map_generator.generate_map()

func _on_party_select_back_pressed():
	show_menu(GameState.MAIN_MENU)

## Called when map generation is complete (initial or after reset)
func _on_map_generation_complete():
	print("Main: Map generation complete, starting game...")
	_town_node_indices_granted_entry.clear()
	# Give party starting supplies (party-wide resources)
	add_party_resource("camping_supplies", 10)
	add_party_resource("health_potion", 1)
	ui_controller.map_ui.initialize_party_ui(current_party_members)
	_refresh_map_resource_labels()
	start_game()

## Start the game - enables player interaction and begins gameplay loop
func start_game():
	if game_started:
		print("Main: Game already started")
		return
	
	game_started = true
	if TimeManager:
		TimeManager.reset_time()
	print("=== Game Started ===")
	print("Party can now navigate the map by clicking on connected nodes")
	
	# Show introductory event
	_show_introductory_event()

## Show the introductory event to the player
func _show_introductory_event():
	# Get the introductory event
	var intro_event = EventManager.events.get("introductory_event_01", {})
	if intro_event.is_empty():
		push_warning("Main: Introductory event not found in EventManager")
		return
	
	# Build party dictionary for event
	var party_dict = _build_party_dict()
	
	# Present the event (filter choices, interpolate text)
	var presented_event = EventManager.present_event(intro_event, party_dict)
	
	# Display the event with current node (for rest state effects)
	var current_node = map_generator.current_party_node
	ui_controller.event_log.append_event(presented_event, party_dict, current_node)

## Called when combat ends. Sets rest safety. Rewards are applied later when user clicks Continue on rewards panel.
func _on_combat_ended(victory: bool, rewards: Dictionary):
	var fled: bool = rewards.get("fled", false)
	# Set rest safety at current node: safe only on victory; flee/defeat = not safe
	var node = map_generator.current_party_node
	if node != null:
		node.can_rest_here = victory
	# Capture the matching post-combat outcome from the originating event (if any).
	var outcomes: Dictionary = EventManager.pending_combat_outcomes
	EventManager.pending_combat_outcomes = {}
	var outcome_key: String
	if victory:
		outcome_key = "victory"
	elif fled:
		outcome_key = "party_fled"
	else:
		outcome_key = "defeat"
	var outcome = outcomes.get(outcome_key, null)
	_pending_combat_outcome = outcome if outcome is Dictionary else {}
	# Rewards are applied silently in on_combat_scene_fully_ended before the outcome event is shown

## Apply rewards to party. Called from CombatScene when user clicks Continue on rewards panel.
func apply_combat_rewards(victory: bool, rewards: Dictionary):
	var xp: int = rewards.get("xp", 0)
	var gold: int = rewards.get("gold", 0)
	var fled: bool = rewards.get("fled", false)
	if victory:
		for member in current_party_members:
			member.gain_experience(xp)
		party_gold += gold
	elif fled:
		for member in current_party_members:
			member.gain_experience(xp)
	_refresh_map_resource_labels()
	if xp > 0:
		ui_controller.map_ui.refresh_party_xp()

## Called by CombatScene after rewards panel is dismissed (or immediately on defeat).
## Restores the map and fires any post-combat outcome event, or shows the game-over screen.
func on_combat_scene_fully_ended(victory: bool, rewards: Dictionary):
	var fled: bool = rewards.get("fled", false)
	var defeat: bool = not victory and not fled
	if defeat:
		_show_game_over()
		return
	map_generator.visible = true
	ui_controller.map_ui.visible = true
	refresh_rest_button_visibility()
	refresh_town_button_visibility()
	apply_combat_rewards(victory, rewards)
	_show_combat_outcome(_pending_combat_outcome, rewards)
	_pending_combat_outcome = {}

## Display a post-combat outcome as a one-choice "Aftermath" event window.
## Rewards are displayed as a block between the narrative text and the Continue button.
func _show_combat_outcome(outcome: Dictionary, rewards: Dictionary):
	var has_text: bool = outcome.has("text")
	var has_rewards: bool = rewards.get("xp", 0) > 0 or rewards.get("gold", 0) > 0
	if not has_text and not has_rewards:
		return
	var outcome_event: Dictionary = {
		"id": "_combat_outcome",
		"title": outcome.get("title", "Aftermath"),
		"choices": [
			{
				"id": "continue",
				"text": "Continue",
				"effects": outcome.get("effects", []),
				"next_event": null
			}
		]
	}
	if has_text:
		outcome_event["text"] = outcome["text"]
	if has_rewards:
		outcome_event["rewards"] = rewards
	var party_dict = _build_party_dict()
	var current_node = map_generator.current_party_node
	ui_controller.event_log.append_event(outcome_event, party_dict, current_node)

## Show the game-over screen as an event window with New Game / Main Menu / Quit.
func _show_game_over():
	var game_over_event: Dictionary = {
		"id": "_game_over",
		"title": "Party Wiped",
		"text": "The last of your companions falls. The forest goes quiet save for the sound of crows gathering overhead. Whatever you were hoping to find out there dies with you here.",
		"choices": [
			{
				"id": "new_game",
				"text": "New Game",
				"effects": [{"type": "script_hook", "hook_name": "restart_game"}],
				"next_event": null
			},
			{
				"id": "main_menu",
				"text": "Main Menu",
				"effects": [{"type": "script_hook", "hook_name": "go_to_main_menu"}],
				"next_event": null
			},
			{
				"id": "quit",
				"text": "Quit",
				"effects": [{"type": "script_hook", "hook_name": "quit_game"}],
				"next_event": null
			}
		]
	}
	var party_dict = _build_party_dict()
	ui_controller.event_log.append_event(game_over_event, party_dict, null)

## Launch an event for a node after travel completes
## Checks for assigned events, falls back to generic placeholder if none found
func _launch_node_event(node: MapNode2D):
	# Get biome name from node
	var biome_name = "plains"
	if node.biome:
		biome_name = node.biome.biome_name
	
	# Build party dictionary for event system
	var party_dict = _build_party_dict()
	
	# Try to pick an event for this node (town nodes use biome-specific town_entry events)
	var node_state = {}
	node_state["current_node"] = node
	node_state["is_town"] = node.is_town

	var selected_event = EventManager.pick_event_for_node(biome_name, party_dict, node_state)
	
	# Check if event was found
	if selected_event.is_empty():
		push_warning("Main: Generic arrival event not found in EventManager")
		return
	
	# Present the event (filter choices, interpolate text)
	var presented_event = EventManager.present_event(selected_event, party_dict)
	
	# Display the event with current node (for rest state effects)
	ui_controller.event_log.append_event(presented_event, party_dict, node)

## Build party dictionary for event system
## This is mainly for text interpolation (like {{party.member1_name}})
## Tag-based condition checking uses TagManager directly, not this dictionary
func _build_party_dict() -> Dictionary:
	var party_dict = {}
	
	# Add party members array (for EventManager internal use)
	party_dict.members = []
	for member in current_party_members:
		var member_dict = {
			"name": member.member_name,
			"level": member.level,
			"health": member.current_health,
			"max_health": member.max_health,
			"experience": member.experience,
			"stats": member.get_final_stats()
		}
		party_dict.members.append(member_dict)
	
	# Add individual member names for easy interpolation
	# Accessible as {{party.member1_name}}, {{party.member2_name}}, {{party.member3_name}}
	if current_party_members.size() > 0:
		party_dict.member1_name = current_party_members[0].member_name
		party_dict.member1_level = current_party_members[0].level
		party_dict.member1_health = current_party_members[0].current_health
	if current_party_members.size() > 1:
		party_dict.member2_name = current_party_members[1].member_name
		party_dict.member2_level = current_party_members[1].level
		party_dict.member2_health = current_party_members[1].current_health
	if current_party_members.size() > 2:
		party_dict.member3_name = current_party_members[2].member_name
		party_dict.member3_level = current_party_members[2].level
		party_dict.member3_health = current_party_members[2].current_health
	
	# Add party-wide stats
	party_dict.party_level = _calculate_average_party_level()
	party_dict.leader_name = current_party_members[0].member_name if current_party_members.size() > 0 else ""
	
	# Add reputation (empty for now, can be populated later if needed)
	party_dict.reputation = {}

	# Add variables (empty for now, can be populated later if needed)
	party_dict.variables = {}

	# Party gold (for event conditions e.g. min_gold, and interpolation)
	party_dict.party_gold = party_gold

	return party_dict

## Calculate average party level
func _calculate_average_party_level() -> int:
	if current_party_members.is_empty():
		return 1
	
	var total_level = 0
	for member in current_party_members:
		total_level += member.level
	
	return int(total_level / current_party_members.size())

# ============================================================================
# REST SYSTEM
# ============================================================================

## Called when party moves to a new node
func _on_party_moved_to_node(node: MapNode2D):
	pass  # Rest button visibility is handled by MapGenerator2D

## Called when event window closes - update rest and town button visibility
func _on_event_closed():
	refresh_rest_button_visibility()
	refresh_town_button_visibility()
	_refresh_map_resource_labels()

const CAMPING_SUPPLIES_ITEM_ID: String = "camping_supplies"
const HEALTH_POTION_ITEM_ID: String = "health_potion"
const HEALTH_POTION_HEAL_PERCENT: int = 50  # Heals 50% of max HP

## Add to party-wide resources (bulk items only). Returns true if added.
func add_party_resource(item_id: String, count: int = 1) -> bool:
	if count <= 0 or not ItemDatabase.is_bulk_loot(item_id):
		return false
	var item := ItemDatabase.get_item(item_id)
	if not item:
		return false
	var current: int = int(party_resources.get(item_id, 0))
	var cap := item.capacity if item.capacity > 0 else 999
	var can_add := mini(count, cap - current)
	if can_add <= 0:
		return false
	party_resources[item_id] = current + can_add
	return true

## Remove from party-wide resources. Returns true if removed.
func remove_party_resource(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var current: int = int(party_resources.get(item_id, 0))
	if current <= 0:
		return false
	var to_remove := mini(count, current)
	party_resources[item_id] = current - to_remove
	if party_resources[item_id] <= 0:
		party_resources.erase(item_id)
	return true

## Get party-wide count for a resource item.
func get_party_resource_count(item_id: String) -> int:
	return int(party_resources.get(item_id, 0))

func _input(event: InputEvent) -> void:
	if _in_potion_target_mode and event.is_action_pressed("ui_cancel"):
		_in_potion_target_mode = false
		ui_controller.cancel_potion_target_selection()
		get_viewport().set_input_as_handled()

func _get_party_camping_supplies() -> int:
	return get_party_resource_count(CAMPING_SUPPLIES_ITEM_ID)

func _get_party_health_potion_count() -> int:
	return get_party_resource_count(HEALTH_POTION_ITEM_ID)

func _spend_party_health_potion() -> bool:
	return remove_party_resource(HEALTH_POTION_ITEM_ID, 1)

## Called when health potion display/button is clicked - enter target selection mode
func _on_health_potion_use_requested():
	if _get_party_health_potion_count() < 1:
		return
	_in_potion_target_mode = true
	ui_controller.request_potion_target_selection()

## Called when player selects a character to heal with health potion
func _on_potion_target_selected(member: PartyMember):
	if not member or member.current_health >= member.max_health:
		return
	if not _spend_party_health_potion():
		return
	_in_potion_target_mode = false
	ui_controller.cancel_potion_target_selection()
	var heal_amount: int = max(10, member.max_health * HEALTH_POTION_HEAL_PERCENT / 100)
	member.heal(heal_amount)
	_refresh_map_resource_labels()
	if ui_controller.map_ui and ui_controller.map_ui.has_method("update_resource_labels"):
		ui_controller.map_ui.update_resource_labels(current_party_members, party_gold, party_resources)

## Update rest button visibility from current node's rest state (safe to rest and not already rested here).
## Wilderness rest requires at least 1 camping supply - hide Rest button when party has none.
## At towns, hide Rest button (use Inn via Town button instead).
func refresh_rest_button_visibility():
	var current_node = map_generator.current_party_node
	if current_node == null:
		ui_controller.map_ui.update_rest_button_visibility(false)
		return
	var has_rested_here = current_node.node_index == map_generator.rested_at_node_index
	var has_supplies_for_rest := _get_party_camping_supplies() >= 1
	var at_town: bool = current_node.is_town
	ui_controller.map_ui.update_rest_button_visibility(not at_town and current_node.can_rest_here and not has_rested_here and has_supplies_for_rest)

## Called when player clicks a node and travel begins - hide Town button immediately
func _on_travel_started(_from_node: MapNode2D, _target_node: MapNode2D):
	ui_controller.map_ui.update_town_button_visibility(false)

## Called when travel completes - advance time and launch event for the destination node
func _on_travel_completed(node: MapNode2D, path_distance: float):
	# Advance world time based on path length
	if TimeManager:
		TimeManager.advance_time_from_travel(path_distance)
	# Launch event for this node after travel completes
	_launch_node_event(node)

## Called when rest button is pressed (from MapGenerator2D)
func _on_rest_requested():
	start_rest()

## Start resting at the current node
## Called when player clicks the rest button (wilderness rest - requires camping supplies)
func start_rest():
	# Check if party can rest at current location
	var current_node = map_generator.current_party_node
	if not current_node.can_rest_here:
		print("Main: Cannot rest at current node")
		return
	# Wilderness rest requires at least 1 camping supply - block entering rest screen if none
	if _get_party_camping_supplies() < 1:
		print("Main: Cannot rest - no camping supplies")
		return

	print("Main: Starting rest at node %d" % current_node.node_index)
	
	# Hide map and map UI
	map_generator.visible = false
	ui_controller.map_ui.visible = false
	
	# Show rest screen with party for rest abilities and healing
	ui_controller.rest_controller.start_rest(current_party_members)

## Called when rest is interrupted by nighttime ambush (before combat starts)
func _on_rest_ambush_triggered():
	_town_node_for_rest = null

## Called when rest is complete - return to map or back to town if we rested from Inn
func _on_rest_complete():
	print("Main: Rest complete")
	_refresh_map_resource_labels()
	# Mark that the party has rested at the current node
	map_generator.mark_node_as_rested()
	var current_node = map_generator.current_party_node
	if current_node:
		ui_controller.map_ui.update_rest_button_visibility(false)
	ui_controller.rest_controller.visible = false
	if _town_node_for_rest != null:
		# Return to town screen instead of map
		_town_node_for_rest.can_rest_here = true
		open_town_screen(_town_node_for_rest)
		_town_node_for_rest = null
		return
	map_generator.visible = true
	ui_controller.map_ui.visible = true

# ============================================================================
# TOWN SYSTEM
# ============================================================================

## Open the town screen for the given town node (called by open_town effect or Town button).
## When force_all_services is true, show all town options (e.g. master/override event town).
## Marks the town as granted entry so the Town button can re-open it later.
func open_town_screen(town_node: MapNode2D, force_all_services: bool = false):
	town_node.can_rest_here = true
	if _town_node_indices_granted_entry.find(town_node.node_index) < 0:
		_town_node_indices_granted_entry.append(town_node.node_index)
	ui_controller.town_screen.open_town(town_node, current_party_members, party_gold, force_all_services)
	ui_controller.town_screen.visible = true
	map_generator.visible = false
	ui_controller.map_ui.visible = false

## Called when player leaves town
func _on_town_screen_closed():
	ui_controller.town_screen.visible = false
	map_generator.visible = true
	_refresh_map_resource_labels()
	refresh_rest_button_visibility()
	refresh_town_button_visibility()
	ui_controller.map_ui.visible = true

## Town button pressed - re-enter the current town (only shown when at a granted-entry town)
func _on_town_requested():
	var current_node: MapNode2D = map_generator.current_party_node
	if not current_node or not current_node.is_town:
		return
	if _town_node_indices_granted_entry.find(current_node.node_index) < 0:
		return
	open_town_screen(current_node)

## Update Town button visibility. Visible when at a town node the player has been granted entry to.
func refresh_town_button_visibility():
	var current_node: MapNode2D = map_generator.current_party_node
	if current_node == null:
		ui_controller.map_ui.update_town_button_visibility(false)
		return
	var can_show: bool = current_node.is_town and _town_node_indices_granted_entry.has(current_node.node_index)
	ui_controller.map_ui.update_town_button_visibility(can_show)

## Called when player uses Inn in town: start rest and return to town when done
func _on_rest_from_town_requested(town_node: MapNode2D, gold_cost: int):
	if party_gold < gold_cost:
		return
	party_gold -= gold_cost
	_town_node_for_rest = town_node
	ui_controller.town_screen.visible = false
	ui_controller.rest_controller.start_rest(current_party_members, true)  # Inn = safe rest, no ambush
	ui_controller.rest_controller.visible = true

## Called when player buys XP from Warmaster in town
func _on_warmaster_training_requested(member_index: int, gold_cost: int, xp_amount: int):
	if member_index < 0 or member_index >= current_party_members.size():
		return
	if party_gold < gold_cost:
		return
	party_gold -= gold_cost
	current_party_members[member_index].gain_experience(xp_amount)
	ui_controller.town_screen.update_party_gold(party_gold)

## Called when player requests vendor from town
func _on_vendor_requested():
	open_vendor_screen(null, [])

## Open vendor screen. Pass optional vendor_item_ids to restrict inventory; empty = all items.
## Called by EventManager (script_hook open_merchant_ui, open_vendor effect) or from town.
func open_vendor_screen(_context_node: MapNode2D = null, vendor_item_ids: Array = []):
	_vendor_opened_from_town = _context_node == null and ui_controller.town_screen.visible
	ui_controller.vendor_screen.open_vendor(current_party_members, party_gold, vendor_item_ids)
	ui_controller.vendor_screen.visible = true
	map_generator.visible = false
	ui_controller.map_ui.visible = false
	ui_controller.event_log.close()
	if ui_controller.town_screen.visible:
		ui_controller.town_screen.visible = false

## Called when player closes vendor
func _on_vendor_closed():
	ui_controller.vendor_screen.visible = false
	if _vendor_opened_from_town:
		ui_controller.town_screen.visible = true
	else:
		map_generator.visible = true
		ui_controller.map_ui.visible = true
	_refresh_map_resource_labels()

## Called when gold changes in vendor (buy/sell)
func _on_vendor_gold_changed(new_gold: int):
	party_gold = new_gold
	ui_controller.town_screen.update_party_gold(party_gold)
	_refresh_map_resource_labels()

## Called when player requests blacksmith from town
func _on_blacksmith_requested():
	_blacksmith_opened_from_town = true
	ui_controller.town_screen.visible = false
	ui_controller.blacksmith_screen.open_blacksmith(current_party_members, party_gold)
	ui_controller.blacksmith_screen.visible = true

## Called when player closes blacksmith
func _on_blacksmith_closed():
	ui_controller.blacksmith_screen.visible = false
	if _blacksmith_opened_from_town:
		ui_controller.town_screen.visible = true
	_blacksmith_opened_from_town = false
	_refresh_map_resource_labels()

## Called when gold changes in blacksmith (upgrade paid with gold)
func _on_blacksmith_gold_changed(new_gold: int):
	party_gold = new_gold
	ui_controller.town_screen.update_party_gold(party_gold)
	_refresh_map_resource_labels()

## Refresh the MapUI resource count labels (gold + 4 bulk items)
func _refresh_map_resource_labels():
	if ui_controller.map_ui.has_method("update_resource_labels"):
		ui_controller.map_ui.update_resource_labels(current_party_members, party_gold, party_resources)
