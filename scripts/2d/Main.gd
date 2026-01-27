extends Control

## Main game manager - handles overall game state, menus, and coordination
## Central script for game-wide logic

@onready var map_generator: MapGenerator2D = $MapGenerator
@onready var main_menu: MainMenu = $MainMenu
@onready var party_select_menu: PartySelectMenu = $PartySelectMenu
@onready var ui_controller: UIController = $GameUI
@onready var event_window: Control = $EventWindow
@onready var rest_controller: RestController = $RestController

# Game state
enum GameState {
	MAIN_MENU,
	PARTY_SELECT,
	IN_GAME
}

var current_state: GameState = GameState.MAIN_MENU
var game_started: bool = false
var current_world_name: String = ""
var current_party_members: Array[PartyMember] = []
var party_has_traveled: bool = false  # Track if party has actually traveled (not just initial spawn)

func _ready():
	# Connect menu signals automatically
	_connect_menu_signals()
	
	# Initialize menu visibility
	show_menu(GameState.MAIN_MENU)
	
	# Hide map generator until game starts
	map_generator.visible = false
	map_generator.map_generation_complete.connect(_on_map_generation_complete)
	map_generator.party_moved_to_node.connect(_on_party_moved_to_node)
	map_generator.travel_completed.connect(_on_travel_completed)
	map_generator.rest_requested.connect(_on_rest_requested)
	
	# Hide and connect rest controller
	rest_controller.visible = false
	rest_controller.rest_complete.connect(_on_rest_complete)
	
	# Connect event window signal to update rest button when event closes
	event_window.event_closed.connect(_on_event_closed)

## Automatically connect all menu signals
func _connect_menu_signals():
	main_menu.start_game_pressed.connect(_on_main_menu_start_pressed)
	main_menu.quit_pressed.connect(_on_main_menu_quit_pressed)
	
	party_select_menu.start_game_pressed.connect(_on_party_select_start_pressed)
	party_select_menu.back_to_main_menu_pressed.connect(_on_party_select_back_pressed)

## Show a specific menu and hide others
func show_menu(state: GameState):
	current_state = state
	
	# Hide all menus
	main_menu.visible = false
	party_select_menu.visible = false
	map_generator.visible = false
	
	# Update UI visibility based on game state
	ui_controller.update_ui_visibility(state)
	
	# Show the appropriate menu
	match state:
		GameState.MAIN_MENU:
			main_menu.visible = true
		GameState.PARTY_SELECT:
			party_select_menu.visible = true
		GameState.IN_GAME:
			map_generator.visible = true

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

## Called when map generation is complete
func _on_map_generation_complete():
	print("Main: Map generation complete, starting game...")
	start_game()

## Start the game - enables player interaction and begins gameplay loop
func start_game():
	if game_started:
		print("Main: Game already started")
		return
	
	game_started = true
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
	event_window.display_event(presented_event, party_dict, current_node)

## Launch an event for a node after travel completes
## Checks for assigned events, falls back to generic placeholder if none found
func _launch_node_event(node: MapNode2D):
	# Get biome name from node
	var biome_name = "plains"
	if node.biome:
		biome_name = node.biome.biome_name
	
	# Build party dictionary for event system
	var party_dict = _build_party_dict()
	
	# Try to pick an event for this node
	var node_state = {}
	node_state["current_node"] = node
	
	var selected_event = EventManager.pick_event_for_node(biome_name, party_dict, node_state)
	
	# Check if event was found
	if selected_event.is_empty():
		push_warning("Main: Generic arrival event not found in EventManager")
		return
	
	# Present the event (filter choices, interpolate text)
	var presented_event = EventManager.present_event(selected_event, party_dict)
	
	# Display the event with current node (for rest state effects)
	event_window.display_event(presented_event, party_dict, node)

## Build party dictionary for event system
## This is mainly for text interpolation (like {{party.member1_name}})
## Tag-based condition checking uses TagManager directly, not this dictionary
func _build_party_dict() -> Dictionary:
	var party_dict = {}
	
	# Add party members array (for EventManager internal use)
	party_dict.members = []
	for member in current_party_members:
		var member_dict = {
			"name": member.member_name
		}
		party_dict.members.append(member_dict)
	
	# Add individual member names for easy interpolation
	# Accessible as {{party.member1_name}}, {{party.member2_name}}, {{party.member3_name}}
	if current_party_members.size() > 0:
		party_dict.member1_name = current_party_members[0].member_name
	if current_party_members.size() > 1:
		party_dict.member2_name = current_party_members[1].member_name
	if current_party_members.size() > 2:
		party_dict.member3_name = current_party_members[2].member_name
	
	# Add reputation (empty for now, can be populated later if needed)
	party_dict.reputation = {}
	
	# Add variables (empty for now, can be populated later if needed)
	party_dict.variables = {}
	
	return party_dict

# ============================================================================
# REST SYSTEM
# ============================================================================

## Called when party moves to a new node
func _on_party_moved_to_node(node: MapNode2D):
	pass  # Rest button visibility is handled by MapGenerator2D

## Called when event window closes - update rest button visibility
func _on_event_closed():
	# Update rest button visibility based on current node's rest state
	var current_node = map_generator.current_party_node
	map_generator.update_rest_button_visibility(current_node.can_rest_here)

## Called when travel completes - launch event for the destination node
func _on_travel_completed(node: MapNode2D):
	# Launch event for this node after travel completes
	_launch_node_event(node)

## Called when rest button is pressed (from MapGenerator2D)
func _on_rest_requested():
	start_rest()

## Start resting at the current node
## Called when player clicks the rest button
func start_rest():
	# Check if party can rest at current location
	var current_node = map_generator.current_party_node
	if not current_node.can_rest_here:
		print("Main: Cannot rest at current node")
		return
	
	print("Main: Starting rest at node %d" % current_node.node_index)
	
	# Hide map
	map_generator.visible = false
	
	# Show rest screen
	rest_controller.start_rest()

## Called when rest is complete - return to map
func _on_rest_complete():
	print("Main: Rest complete, returning to map")
	
	# Mark that the party has rested at the current node
	map_generator.mark_node_as_rested()
	
	# Hide rest screen
	rest_controller.visible = false
	
	# Show map
	map_generator.visible = true
