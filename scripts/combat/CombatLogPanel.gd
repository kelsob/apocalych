extends Control
class_name CombatLogPanel

@onready var margin_container: MarginContainer = $MarginContainer
@onready var scroll_container: ScrollContainer = $MarginContainer/CombatLogContainer
@onready var log_label: RichTextLabel = $MarginContainer/CombatLogContainer/CombatLogLabel


func _ready() -> void:
	if log_label:
		log_label.bbcode_enabled = true


func append_bbcode(message: String, centered: bool = false) -> void:
	if log_label == null:
		return
	if centered:
		log_label.append_text("[center]%s[/center]\n" % message)
	else:
		log_label.append_text("%s\n" % message)


func clear_log() -> void:
	if log_label:
		log_label.clear()
