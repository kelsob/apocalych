extends PanelContainer

## TurnOrderEntry - UI element representing a single turn in the turn order display
## Shows whose turn it is and the timing. Hover highlights all entries for the same character.

# Node references
@onready var character_name_label: Label = $MarginContainer/VBoxContainer/CharacterNameLabel
@onready var turn_time_label: Label = $MarginContainer/VBoxContainer/TurnTimeLabel
@onready var highlight_rect: NinePatchRect = $HighlightRect
@onready var action_label : Label = $MarginContainer/VBoxContainer/ActionLabel

# Is this the current/next turn?
var is_current_turn: bool = false
# Set by TurnOrderPanel when building the list; used for hover highlight grouping
var combatant: CombatantData = null
var turn_order_panel: Node = null

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_combatant_and_panel(p_combatant: CombatantData, p_panel: Node) -> void:
	combatant = p_combatant
	turn_order_panel = p_panel

func set_highlight(visible: bool) -> void:
	highlight_rect.visible = visible

func _on_mouse_entered() -> void:
	if turn_order_panel and turn_order_panel.has_method("highlight_entries_for_combatant") and combatant:
		turn_order_panel.highlight_entries_for_combatant(combatant)

func _on_mouse_exited() -> void:
	if turn_order_panel and turn_order_panel.has_method("unhighlight_all_entries"):
		turn_order_panel.unhighlight_all_entries()

## Update the display with turn information
func update_display(character_name: String, turn_time: float, is_next_turn: bool = false, action_text: String = ""):
	is_current_turn = is_next_turn
	
	# Update labels
	if is_next_turn:
		character_name_label.text = "→ %s" % character_name
	else:
		character_name_label.text = character_name
	
	turn_time_label.text = "%.2f" % turn_time
	if action_label:
		action_label.text = action_text
	
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
