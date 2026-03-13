extends MarginContainer
class_name EventChoice

## EventChoice - A single selectable choice entry in the EventLog.
## Root is a Label. $Button handles clicks. Supports three visual states.
## States: AVAILABLE (default), SELECTED (green - chosen), REJECTED (gray - not chosen)
@onready var button: Button = $Button
@onready var choice_text: Label = $HBoxContainer/Label
@onready var choice_icon: TextureRect = $HBoxContainer/TextureRect

var choice_data: Dictionary = {}
var _pending_choice: Dictionary = {}

enum State { AVAILABLE, SELECTED, REJECTED }
var _state: State = State.AVAILABLE

signal choice_selected(choice: Dictionary)

func _ready():
	if button:
		button.pressed.connect(_on_button_pressed)
	else:
		push_error("EventChoiceButton: Button node not found")
	if not _pending_choice.is_empty():
		_apply_choice_data(_pending_choice)

## Set the choice data and update display
func set_choice_data(choice: Dictionary):
	choice_data = choice
	_pending_choice = choice
	if choice_text:
		_apply_choice_data(choice)

func _apply_choice_data(choice: Dictionary):
	choice_text.text = choice.get("text", "Choice")
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
