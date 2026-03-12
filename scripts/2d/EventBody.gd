extends MarginContainer
class_name EventBody

## EventBody - Displays the narrative body text of an event entry in the EventLog
## Scene expects: $BodyLabel (Label or RichTextLabel)

@onready var body_label: Label = $BodyLabel

var _pending_text: String = ""

func _ready():
	if _pending_text:
		body_label.text = _pending_text

## Set the body text. Safe to call before or after the node is in the scene tree.
func set_body(text: String):
	_pending_text = text
	if body_label:
		body_label.text = text
