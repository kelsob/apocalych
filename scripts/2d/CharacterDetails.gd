extends Control

@onready var name_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var class_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var race_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/RaceLabel
@onready var level_label: Label = $MarginContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel

func set_member(member: PartyMember) -> void:
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
