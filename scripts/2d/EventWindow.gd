extends Control
class_name EventWindow

## EventWindow - Displays narrative events to the player
## Handles event display, choice presentation, and effect application

# References to UI elements (assumes EventWindow.tscn structure)
@onready var title_label: Label = $MarginContainer/MarginContainer/ContentContainer/TitleLabel
@onready var text_label: Label = $MarginContainer/MarginContainer/ContentContainer/TextLabel
@onready var choices_container: VBoxContainer = $MarginContainer/MarginContainer/ContentContainer/MarginContainer/ChoicesContainer

# Reference to EventChoiceButton scene (set in editor or load at runtime)
var choice_button_scene: PackedScene = null

# Current event data
var current_event: Dictionary = {}
var current_party: Dictionary = {}

# Signals
signal choice_made(choice_id: String, effects: Array)
signal event_closed()

func _ready():
	# Hide window initially
	visible = false
	
	# Try to load EventChoiceButton scene
	choice_button_scene = load("res://scenes/2d/EventChoiceButton.tscn")
	if not choice_button_scene:
		push_error("EventWindow: Could not load EventChoiceButton scene")

## Display an event to the player
## event: Dictionary - The event data (should be pre-processed by EventManager.present_event)
## party: Dictionary - Party state dictionary
func display_event(event: Dictionary, party: Dictionary):
	if event.is_empty():
		push_error("EventWindow: Cannot display empty event")
		return
	
	current_event = event
	current_party = party
	
	# Set title
	if title_label and event.has("title"):
		title_label.text = event.title
	else:
		title_label.text = "Event"
	
	# Set event text
	if text_label and event.has("text"):
		text_label.text = event.text
	else:
		text_label.text = "Something happens..."
	
	# Clear existing choices
	_clear_choices()
	
	# Create choice buttons
	var choices = event.get("choices", [])
	
	# Ensure at least one choice exists (fallback "Continue" button)
	if choices.is_empty():
		choices = [_create_default_continue_choice()]
	
	for choice in choices:
		_create_choice_button(choice)
	
	# Show window and pause game
	visible = true
	_pause_gameplay()

## Create a choice button from a choice dictionary
func _create_choice_button(choice: Dictionary):
	if not choice_button_scene:
		push_error("EventWindow: Cannot create choice button - scene not loaded")
		return
	
	if not choices_container:
		push_error("EventWindow: Choices container not found")
		return
	
	var choice_button = choice_button_scene.instantiate()
	if not choice_button:
		push_error("EventWindow: Failed to instantiate choice button")
		return
	
	# Configure the choice button
	choice_button.set_choice_data(choice)
	
	# Connect choice selected signal
	choice_button.choice_selected.connect(_on_choice_button_pressed)
	
	choices_container.add_child(choice_button)

## Handle choice button press
## choice: Dictionary - The choice data from EventChoiceButton
func _on_choice_button_pressed(choice: Dictionary):
	var choice_id = choice.get("id", "")
	var effects = choice.get("effects", [])
	
	# Emit signal
	choice_made.emit(choice_id, effects)
	
	# Apply effects via EventManager
	if EventManager and effects.size() > 0:
		EventManager.apply_effects(effects, current_party, {})
	
	# Close event window
	close()

## Close the event window
func close():
	# Hide window
	visible = false
	
	# Clear event data
	current_event = {}
	current_party = {}
	
	# Clear choices
	_clear_choices()
	
	# Resume gameplay
	_resume_gameplay()
	
	# Emit signal
	event_closed.emit()

## Create default "Continue" choice if event has no choices
func _create_default_continue_choice() -> Dictionary:
	return {
		"id": "continue",
		"text": "Continue",
		"condition": {
			"requires_tags": [],
			"forbids_tags": []
		},
		"effects": [],
		"next_event": null,
		"weight": 1
	}

## Clear all choice buttons
func _clear_choices():
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()

## Pause gameplay (disable map interaction)
func _pause_gameplay():
	# Get map generator and set pause flag
	var main = get_tree().get_first_node_in_group("main") if get_tree() else null
	if main:
		var map_generator = main.get_node_or_null("MapGenerator")
		if map_generator:
			# Set pause flag to prevent all map interaction
			map_generator.events_paused = true
			# Also disable process/input as backup
			map_generator.set_process_input(false)
			map_generator.set_process(false)
			# Clear any existing hover preview
			map_generator._clear_hover_preview()

## Resume gameplay (enable map interaction)
func _resume_gameplay():
	# Get map generator and clear pause flag
	var main = get_tree().get_first_node_in_group("main") if get_tree() else null
	if main:
		var map_generator = main.get_node_or_null("MapGenerator")
		if map_generator:
			# Clear pause flag to re-enable map interaction
			map_generator.events_paused = false
			# Re-enable process/input
			map_generator.set_process_input(true)
			map_generator.set_process(true)
