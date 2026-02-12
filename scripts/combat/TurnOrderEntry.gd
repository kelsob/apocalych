extends PanelContainer

## TurnOrderEntry - UI element representing a single turn in the turn order display
## Shows whose turn it is and the timing

# Node references
@onready var character_name_label: Label = $VBoxContainer/CharacterNameLabel
@onready var turn_time_label: Label = $VBoxContainer/TurnTimeLabel

# Is this the current/next turn?
var is_current_turn: bool = false

## Update the display with turn information
func update_display(character_name: String, turn_time: float, is_next_turn: bool = false):
	is_current_turn = is_next_turn
	
	# Update labels
	if is_next_turn:
		character_name_label.text = "→ %s" % character_name
	else:
		character_name_label.text = character_name
	
	turn_time_label.text = "%.2f" % turn_time
	
	# Highlight if this is the next turn
	if is_next_turn:
		character_name_label.add_theme_color_override("font_color", Color.YELLOW)
		modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint
	else:
		character_name_label.add_theme_color_override("font_color", Color.WHITE)
		modulate = Color.WHITE

## Set character name only
func set_character_name(character_name: String):
	character_name_label.text = character_name

## Set turn time only
func set_turn_time(turn_time: float):
	turn_time_label.text = "%.2f" % turn_time
