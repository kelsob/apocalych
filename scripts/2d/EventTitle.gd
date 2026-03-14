extends MarginContainer
class_name EventTitle

@onready var title_label: RichTextLabel = $TitleLabel

## Shadow offset in pixels (applied to both X and Y).
@export var shadow_offset: int = 4

var _pending_text: String = ""

func _ready():
	# Apply shadow using the same color as the font outline, so they always match.
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
