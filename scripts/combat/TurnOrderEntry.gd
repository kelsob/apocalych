extends Control
## TurnOrderEntry - UI element representing a single turn in the turn order display
## Shows whose turn it is and the timing. Hover highlights all entries for the same character.

# Node references
@onready var character_name_label: Label = $CharacterNameLabel
@onready var turn_time_label: Label = $TurnTimeLabel
@onready var highlight_rect: NinePatchRect = $HighlightRect
@onready var action_label : Label = $ActionLabel
@onready var portrait_texture: TextureRect = $MarginContainer2/PortraitTexture

# Is this the current/next turn?
var is_current_turn: bool = false
# Set by TurnOrderPanel when building the list; used for hover highlight grouping
var combatant: CombatantData = null
var turn_order_panel: Node = null

func _ready() -> void:
	character_name_label.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_combatant_and_panel(p_combatant: CombatantData, p_panel: Node) -> void:
	combatant = p_combatant
	turn_order_panel = p_panel
	_update_portrait()

func set_highlight(highlighted: bool) -> void:
	highlight_rect.modulate.a = 1.0 if highlighted else 0.5

func _on_mouse_entered() -> void:
	character_name_label.visible = true
	if turn_order_panel and turn_order_panel.has_method("highlight_entries_for_combatant") and combatant:
		turn_order_panel.highlight_entries_for_combatant(combatant)

func _on_mouse_exited() -> void:
	character_name_label.visible = false
	if turn_order_panel and turn_order_panel.has_method("unhighlight_all_entries"):
		turn_order_panel.unhighlight_all_entries()

## Update the display with turn information.
## cast_countdown: remaining cast ticks for an active channeled/delayed ability; 0 = no active cast.
func update_display(character_name: String, is_next_turn: bool = false, action_text: String = "", cast_countdown: int = 0):
	is_current_turn = is_next_turn

	if is_next_turn:
		character_name_label.text = "→ %s" % character_name
	else:
		character_name_label.text = character_name

	turn_time_label.text = "" if cast_countdown <= 0 else str(cast_countdown)
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

## Set cast countdown only. Pass 0 to clear.
func set_cast_countdown(countdown: int):
	turn_time_label.text = "" if countdown <= 0 else str(countdown)

func _update_portrait() -> void:
	if combatant.is_player:
		portrait_texture.texture = (combatant.source as PartyMember).get_combat_portrait()
	else:
		portrait_texture.texture = (combatant.source as Enemy).combat_portrait
