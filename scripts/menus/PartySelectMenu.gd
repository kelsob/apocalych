extends Control
class_name PartySelectMenu

## Party Select Menu - handles party selection UI and signals

signal start_game_pressed(party_members: Array[PartyMember], world_name: String)
signal back_to_main_menu_pressed

# Character select references (you'll assign these in the scene)
@onready var character_select_1: CharacterSelect = $HBoxContainer/CharacterSelect1
@onready var character_select_2: CharacterSelect = $HBoxContainer/CharacterSelect2
@onready var character_select_3: CharacterSelect = $HBoxContainer/CharacterSelect3

# UI references (you'll connect these in the scene)
@onready var start_game_button: Button = $StartGameButton
@onready var back_button: Button = $BackButton
@onready var world_name_input: LineEdit = $HBoxContainer2/WorldNameInput
@onready var randomize_world_name_button: Button = $HBoxContainer2/RandomizeWorldNameButton

@onready var race_description_label : Label = $RaceDescriptionLabel
@onready var class_description_label : Label = $ClassDescriptionLabel

# World name generator
var world_name_generator: WorldNameGenerator = WorldNameGenerator.new()
var world_name: String = ""

func _ready():
	# Connect character select signals
	_connect_character_selects()
	
	# Connect UI buttons
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if randomize_world_name_button:
		randomize_world_name_button.pressed.connect(_on_randomize_world_name_pressed)
	
	# Connect world name input
	if world_name_input:
		world_name_input.text_changed.connect(_on_world_name_changed)
	
	# Auto-generate random characters and world name on load
	randomize_all_characters()
	randomize_world_name()
	
	# Update description labels after initial randomization
	call_deferred("_update_description_labels")

## Connect all character select instances
func _connect_character_selects():
	var character_selects = [character_select_1, character_select_2, character_select_3]
	for char_select in character_selects:
		if char_select:
			char_select.character_data_changed.connect(_on_character_data_changed)

## Called when any character data changes - update start button state and descriptions
func _on_character_data_changed():
	_update_start_button_state()
	_update_description_labels()

## Update start button enabled state based on party completeness
func _update_start_button_state():
	if not start_game_button:
		return
	
	var all_complete = true
	var character_selects = [character_select_1, character_select_2, character_select_3]
	
	for char_select in character_selects:
		if char_select and not char_select.is_complete():
			all_complete = false
			break
	
	start_game_button.disabled = not all_complete

## Get all party members from character selects
func get_party_members() -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	var character_selects = [character_select_1, character_select_2, character_select_3]
	
	for char_select in character_selects:
		if char_select:
			var member = char_select.create_party_member()
			if member:
				members.append(member)
	
	return members

## Button handlers
func _on_start_game_pressed():
	var party = get_party_members()
	if party.size() == 3:  # Ensure we have exactly 3 party members
		# Get current world name from input or use stored value
		var current_world_name = world_name
		if world_name_input and not world_name_input.text.is_empty():
			current_world_name = world_name_input.text
		start_game_pressed.emit(party, current_world_name)

func _on_back_pressed():
	back_to_main_menu_pressed.emit()

func _on_randomize_world_name_pressed():
	randomize_world_name()

func _on_world_name_changed(new_text: String):
	world_name = new_text

## Randomize all three characters
func randomize_all_characters():
	var character_selects = [character_select_1, character_select_2, character_select_3]
	for char_select in character_selects:
		if char_select:
			char_select.randomize_character()

## Randomize world name
func randomize_world_name():
	world_name = world_name_generator.generate_name()
	if world_name_input:
		world_name_input.text = world_name

## Update description labels with current race/class from first character
func _update_description_labels():
	if not character_select_1:
		return
	
	# Update race description
	if race_description_label:
		if character_select_1.selected_race:
			race_description_label.text = character_select_1.selected_race.description
		else:
			race_description_label.text = ""
	
	# Update class description
	if class_description_label:
		if character_select_1.selected_class:
			class_description_label.text = character_select_1.selected_class.description
		else:
			class_description_label.text = ""
