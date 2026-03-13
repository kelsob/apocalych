extends MarginContainer
class_name EventTitle

@onready var title_label: RichTextLabel = $TitleLabel

var _pending_text: String = ""

func _ready():
	if _pending_text:
		title_label.text = "[u]%s[/u]" % _pending_text

## Set the title text. Safe to call before or after the node is in the scene tree.
func set_title(text: String):
	_pending_text = text
	if title_label:
		title_label.text = "[u]%s[/u]" % text
