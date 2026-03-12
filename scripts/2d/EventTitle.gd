extends MarginContainer
class_name EventTitle

## EventTitle - Displays the title of an event entry in the EventLog
## Scene expects: $TitleLabel (Label)

@onready var title_label: Label = $TitleLabel

var _pending_text: String = ""

func _ready():
	if _pending_text:
		title_label.text = _pending_text

## Set the title text. Safe to call before or after the node is in the scene tree.
func set_title(text: String):
	_pending_text = text
	if is_inside_tree() and title_label:
		title_label.text = text
