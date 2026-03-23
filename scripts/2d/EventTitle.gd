extends MarginContainer
class_name EventTitle

@onready var title_label: RichTextLabel = $TitleLabel

## Shadow offset in pixels (applied to both X and Y).
@export var shadow_offset: int = 4

var _pending_text: String = ""
var _intro_tween: Tween = null
var duration: float = 0.10

signal intro_done

func _ready():
	visible = false
	var shadow_color: Color = title_label.get_theme_color("font_outline_color", "RichTextLabel")
	title_label.add_theme_color_override("font_shadow_color", shadow_color)
	title_label.add_theme_constant_override("shadow_offset_x", shadow_offset)
	title_label.add_theme_constant_override("shadow_offset_y", shadow_offset)

	if _pending_text:
		title_label.text = _pending_text

## Set the title text. Safe to call before or after the node is in the scene tree.
func set_title(text: String):
	_pending_text = text
	if title_label:
		title_label.text = text

## Fade in. Awaitable — resolves when animation completes or snap_visible() is called.
func animate_in() -> void:
	if _intro_tween:
		_intro_tween.kill()
	visible = true
	modulate.a = 0.0
	_intro_tween = create_tween()
	_intro_tween.tween_property(self, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(func(): intro_done.emit())
	await intro_done

## Snap to fully visible immediately, resolving any in-flight animate_in await.
func snap_visible() -> void:
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null
	visible = true
	modulate.a = 1.0
	intro_done.emit()
