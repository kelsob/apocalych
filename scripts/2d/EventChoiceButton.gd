extends Label
class_name EventChoiceButton

## EventChoiceButton - Individual choice button for event windows
## Displays choice text and handles selection
## Structure: Label (parent) -> Panel (background) and Button (clickable)

# UI references
@onready var panel: Panel = $Panel
@onready var button: Button = $Button

# Choice data
var choice_data: Dictionary = {}

# Signal emitted when this choice is selected
signal choice_selected(choice: Dictionary)

func _ready():
	# Connect button press to our handler
	if button:
		button.pressed.connect(_on_button_pressed)
	else:
		push_error("EventChoiceButton: Button node not found")

## Set the choice data and update display
func set_choice_data(choice: Dictionary):
	choice_data = choice
	
	# Set label text (this Label is the parent)
	if choice.has("text"):
		text = choice.text
	else:
		text = "Choice"

## Handle button press
func _on_button_pressed():
	# Emit signal with choice data
	choice_selected.emit(choice_data)

## Get the button node (for external connections if needed)
func get_button() -> Button:
	return button
