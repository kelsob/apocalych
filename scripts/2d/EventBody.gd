extends MarginContainer
class_name EventBody

## EventBody - Displays the narrative body text of an event entry in the EventLog
## Scene expects: $BodyLabel (RichTextLabel, bbcode_enabled=false, fit_content=true, scroll_active=false)
## Skip / snap is driven by EventLog (_input over the whole panel), not this node.

@onready var body_label: RichTextLabel = $BodyLabel

## Characters revealed per second. Set by EventLog.
var typewriter_chars_per_second: float = 60.0

var _pending_text: String = ""
var _intro_tween: Tween = null
## True while typewriter / fade intro tween is running — EventLog reads this to skip.
var _typewriter_reveal_active: bool = false

signal intro_done


func is_typewriter_active() -> bool:
	return _typewriter_reveal_active


func _ready():
	visible = false
	if _pending_text:
		body_label.text = _pending_text
		body_label.visible_ratio = 1.0

## Set the body text. Safe to call before or after the node is in the scene tree.
func set_body(text: String):
	_pending_text = text
	if body_label:
		body_label.text = text
		body_label.visible_ratio = 1.0

## Typewriter reveal + fade in. Awaitable — resolves when done or snap_visible() is called.
func animate_in() -> void:
	if _intro_tween:
		_intro_tween.kill()
	_typewriter_reveal_active = true
	visible = true
	modulate.a = 0.0
	body_label.visible_ratio = 0.0
	var char_count: int = body_label.text.length()
	var duration: float = char_count / maxf(typewriter_chars_per_second, 1.0)
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(self, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_LINEAR)
	_intro_tween.tween_property(body_label, "visible_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	_intro_tween.chain().tween_callback(func(): intro_done.emit())
	await intro_done
	_typewriter_reveal_active = false

## Snap to fully visible immediately, resolving any in-flight animate_in await.
func snap_visible() -> void:
	_typewriter_reveal_active = false
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null
	visible = true
	modulate.a = 1.0
	body_label.visible_ratio = 1.0
	intro_done.emit()
