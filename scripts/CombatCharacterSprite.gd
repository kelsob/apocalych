extends Control
class_name CombatCharacterSprite

## CombatCharacterSprite - Displays a combatant in combat; supports targeting selection state

@onready var sprite: Sprite2D = $Sprite2D

# Targeting visuals (created in _ready so we don't require scene edits)
var _selection_highlight: ColorRect = null
var _valid_outline: ColorRect = null

func _ready():
	# Selection indicator: full rect overlay when this combatant is selected as target
	_selection_highlight = ColorRect.new()
	_selection_highlight.color = Color(1.0, 0.9, 0.2, 0.35)
	_selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_highlight.visible = false
	add_child(_selection_highlight)
	# Valid target outline: subtle border when in targeting mode and this is a valid target
	_valid_outline = ColorRect.new()
	_valid_outline.color = Color(0.3, 0.9, 0.3, 0.25)
	_valid_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_valid_outline.visible = false
	add_child(_valid_outline)
	call_deferred("_resize_overlays")

func _resize_overlays():
	var sz = size
	_selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_highlight.set_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_highlight.size = sz
	_valid_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_valid_outline.set_offsets_preset(Control.PRESET_FULL_RECT)
	_valid_outline.size = sz

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if _selection_highlight:
			_selection_highlight.size = size
		if _valid_outline:
			_valid_outline.size = size

## Set the sprite texture
func set_sprite_texture(texture: Texture2D):
	if sprite:
		sprite.texture = texture

## Set sprite modulation (for death/status effects)
func set_sprite_modulation(color: Color):
	if sprite:
		sprite.modulate = color

## Show or hide "selected as target" highlight
func set_selected(selected: bool):
	if _selection_highlight:
		_selection_highlight.visible = selected

## Show or hide "valid target" outline (during targeting mode)
func set_valid_target(valid: bool):
	if _valid_outline:
		_valid_outline.visible = valid

## Clear targeting visuals
func clear_targeting_state():
	set_selected(false)
	set_valid_target(false)
