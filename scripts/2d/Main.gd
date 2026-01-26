extends Control

## Main game manager - handles overall game state, menus, and coordination
## Central script for game-wide logic

@onready var map_generator: MapGenerator2D = $MapGenerator
@onready var main_menu: MainMenu = $MainMenu
@onready var party_select_menu: PartySelectMenu = $PartySelectMenu
@onready var ui_controller: UIController = $GameUI
@onready var event_window: Control = $EventWindow
@onready var rest_controller: RestController = $RestController  # You'll create this node

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

func _ready():
	# Connect menu signals automatically
	_connect_menu_signals()
	
	# Initialize menu visibility
	show_menu(GameState.MAIN_MENU)
	
	# Hide map generator until game starts
	if map_generator:
		map_generator.visible = false
		map_generator.map_generation_complete.connect(_on_map_generation_complete)
		map_generator.party_moved_to_node.connect(_on_party_moved_to_node)
	
	# Hide and connect rest controller
	if rest_controller:
		rest_controller.visible = false
		rest_controller.rest_complete.connect(_on_rest_complete)
	
	# Connect UI controller rest button signal
	if ui_controller:
		ui_controller.rest_requested.connect(_on_rest_requested)

## Automatically connect all menu signals
func _connect_menu_signals():
	if main_menu:
		main_menu.start_game_pressed.connect(_on_main_menu_start_pressed)
		main_menu.quit_pressed.connect(_on_main_menu_quit_pressed)
	
	if party_select_menu:
		party_select_menu.start_game_pressed.connect(_on_party_select_start_pressed)
		party_select_menu.back_to_main_menu_pressed.connect(_on_party_select_back_pressed)

## Show a specific menu and hide others
func show_menu(state: GameState):
	current_state = state
	
	# Hide all menus
	if main_menu:
		main_menu.visible = false
	if party_select_menu:
		party_select_menu.visible = false
	if map_generator:
		map_generator.visible = false
	
	# Update UI visibility based on game state
	if ui_controller:
		ui_controller.update_ui_visibility(state)
	
	# Show the appropriate menu
	match state:
		GameState.MAIN_MENU:
			if main_menu:
				main_menu.visible = true
		GameState.PARTY_SELECT:
			if party_select_menu:
				party_select_menu.visible = true
		GameState.IN_GAME:
			if map_generator:
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
	if map_generator:
		map_generator.set_world_name(world_name)
	
	# Show map generator (will be hidden until map is generated)
	show_menu(GameState.IN_GAME)
	
	# Start map generation now that party is selected
	if map_generator:
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
	if not event_window:
		push_warning("Main: EventWindow not found, cannot show introductory event")
		return
	
	if not EventManager:
		push_warning("Main: EventManager not found, cannot show introductory event")
		return
	
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
	var current_node = map_generator.current_party_node if map_generator else null
	event_window.display_event(presented_event, party_dict, current_node)

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

## Called when party moves to a new node - update rest button visibility
func _on_party_moved_to_node(node: MapNode2D):
	if ui_controller and node:
		ui_controller.update_rest_button_visibility(node.can_rest_here)

## Called when UI controller rest button is pressed
func _on_rest_requested():
	start_rest()

## Start resting at the current node
## Called when player clicks the rest button
func start_rest():
	if not rest_controller:
		push_error("Main: RestController not found")
		return
	
	# Check if party can rest at current location
	var current_node = map_generator.current_party_node if map_generator else null
	if not current_node:
		print("Main: No current node to rest at")
		return
	
	if not current_node.can_rest_here:
		print("Main: Cannot rest at current node")
		return
	
	print("Main: Starting rest at node %d" % current_node.node_index)
	
	# Hide map
	if map_generator:
		map_generator.visible = false
	
	# Show rest screen
	rest_controller.start_rest()

## Called when rest is complete - return to map
func _on_rest_complete():
	print("Main: Rest complete, returning to map")
	
	# Hide rest screen
	if rest_controller:
		rest_controller.visible = false
	
	# Show map
	if map_generator:
		map_generator.visible = true
