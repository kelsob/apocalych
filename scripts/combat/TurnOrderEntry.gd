extends Control
class_name TurnOrderEntry

## Single row in the turn order strip. Hover highlights sibling entries with the same [member CombatantData].

var is_acting_now: bool = false

@export_group("Nudge")
## Slide [member animate_control] right when this row is the current turn or hover-highlighted.
@export var nudge_slide_pixels: float = 6.0
@export var nudge_slide_duration: float = 0.12

@onready var character_name_label: Label = $AnimateControl/CharacterNameLabel
@onready var turn_time_label: Label = $AnimateControl/TurnTimeLabel
@onready var highlight_rect: NinePatchRect = $AnimateControl/HighlightRect
@onready var action_label: Label = $AnimateControl/ActionLabel
@onready var portrait_texture: TextureRect = $AnimateControl/MarginContainer/PortraitTexture
@onready var animate_control: Control = $AnimateControl

var combatant: CombatantData = null
var turn_order_panel: Node = null

var _hover_highlighted: bool = false
var _nudge_tween: Tween = null


func _ready() -> void:
	character_name_label.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if combatant != null:
		call_deferred("_update_portrait")


func _exit_tree() -> void:
	_kill_nudge_tween()


func set_combatant_and_panel(p_combatant: CombatantData, p_panel: Node) -> void:
	combatant = p_combatant
	turn_order_panel = p_panel
	call_deferred("_update_portrait")


func set_highlight(highlighted: bool) -> void:
	_hover_highlighted = highlighted
	_refresh_frame_alpha()
	_tween_nudge_offset()


func _on_mouse_entered() -> void:
	character_name_label.visible = true
	if turn_order_panel and turn_order_panel.has_method("highlight_entries_for_combatant") and combatant:
		turn_order_panel.highlight_entries_for_combatant(combatant)


func _on_mouse_exited() -> void:
	character_name_label.visible = false
	if turn_order_panel and turn_order_panel.has_method("unhighlight_all_entries"):
		turn_order_panel.unhighlight_all_entries()


func update_display(character_name: String, acting_now: bool = false, action_text: String = "", cast_countdown: int = 0) -> void:
	is_acting_now = acting_now
	_refresh_frame_alpha()
	_tween_nudge_offset()
	if character_name_label:
		character_name_label.remove_theme_color_override("font_color")
		character_name_label.text = character_name
	if turn_time_label:
		turn_time_label.text = "" if cast_countdown <= 0 else str(cast_countdown)
	if action_label:
		action_label.text = action_text


func set_character_name(character_name: String) -> void:
	if character_name_label:
		character_name_label.text = character_name


func set_cast_countdown(countdown: int) -> void:
	if turn_time_label:
		turn_time_label.text = "" if countdown <= 0 else str(countdown)


func _refresh_frame_alpha() -> void:
	if not highlight_rect:
		return
	highlight_rect.modulate.a = 1.0 if is_acting_now or _hover_highlighted else 0.35


func _kill_nudge_tween() -> void:
	if _nudge_tween != null:
		if _nudge_tween.is_valid():
			_nudge_tween.kill()
		_nudge_tween = null


func _animate_control_resolve() -> Control:
	if animate_control != null:
		return animate_control
	if is_inside_tree():
		return get_node_or_null(NodePath("AnimateControl")) as Control
	return null


func _tween_nudge_offset() -> void:
	var ac := _animate_control_resolve()
	if ac == null:
		return
	var target_x := nudge_slide_pixels if is_acting_now or _hover_highlighted else 0.0
	if is_equal_approx(ac.position.x, target_x):
		return
	_kill_nudge_tween()
	_nudge_tween = create_tween()
	_nudge_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(ac, ^"position", Vector2(target_x, ac.position.y), nudge_slide_duration)


func _update_portrait() -> void:
	var tex_rect: TextureRect = portrait_texture
	if tex_rect == null:
		tex_rect = get_node_or_null(NodePath("AnimateControl/MarginContainer/PortraitTexture")) as TextureRect
	if tex_rect == null or combatant == null:
		return
	var portrait: Texture2D = null
	if combatant.is_player and combatant.source is HeroCharacter:
		var h: HeroCharacter = combatant.source as HeroCharacter
		portrait = h.get_combat_portrait()
		if portrait == null:
			portrait = h.get_portrait()
	elif not combatant.is_player and combatant.source is Enemy:
		portrait = (combatant.source as Enemy).combat_portrait
	tex_rect.texture = portrait
