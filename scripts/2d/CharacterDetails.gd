extends Control

signal character_clicked(member: PartyMember)

var _member: PartyMember = null

@onready var name_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var class_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var race_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/RaceLabel
@onready var level_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel
@onready var button: Button = $Button

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)

func set_member(member: PartyMember) -> void:
	_member = member
	if not member:
		name_label.text = ""
		level_label.text = ""
		class_label.text = ""
		race_label.text = ""
		return
	name_label.text = member.member_name
	level_label.text = str(member.level)
	class_label.text = member.class_resource.name if member.class_resource else ""
	race_label.text = member.race.race_name if member.race else ""

func _on_button_pressed() -> void:
	if _member:
		character_clicked.emit(_member)
