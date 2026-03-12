extends Label
class_name EventChoice

## EventChoice - A single selectable choice entry in the EventLog.
## Root is a Label. $Button handles clicks. Supports three visual states.
## States: AVAILABLE (default), SELECTED (green - chosen), REJECTED (gray - not chosen)

@onready var panel: Panel = $Panel
@onready var button: Button = $Button

var choice_data: Dictionary = {}

enum State { AVAILABLE, SELECTED, REJECTED }
var _state: State = State.AVAILABLE

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
	
	# Disabled choices are visible but non-interactive and visually dimmed.
	# A choice becomes disabled when requires_item is set but the party lacks the item.
	if choice.get("disabled", false):
		if button:
			button.disabled = true
		modulate = Color(1.0, 1.0, 1.0, 0.4)

## Transition to SELECTED state - the choice the player picked (manuscript green)
func select():
	_state = State.SELECTED
	if button:
		button.disabled = true
	add_theme_color_override("font_color", ProjectColors.EVENT_CHOICE_SELECTED)

## Transition to REJECTED state - a choice the player did not pick (ghosted)
func reject():
	_state = State.REJECTED
	if button:
		button.disabled = true
	add_theme_color_override("font_color", ProjectColors.EVENT_CHOICE_REJECTED)

func _on_button_pressed():
	if _state != State.AVAILABLE:
		return
	choice_selected.emit(choice_data)
