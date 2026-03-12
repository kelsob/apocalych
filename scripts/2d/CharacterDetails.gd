extends Control

signal character_clicked(member: PartyMember)

var _member: PartyMember = null

@onready var name_label: Label = $HBoxContainer/VBoxContainer/VBoxContainer/NameLabel
@onready var class_label: Label = $HBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var race_label: Label = $HBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/RaceLabel
@onready var level_label: Label = $HBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

@onready var hp_progress_bar: HPBar = $HBoxContainer/VBoxContainer/HPBar
@onready var xp_progress_bar: XPBar = $HBoxContainer/VBoxContainer/ExpBar

@onready var portrait_texture: TextureRect = $HBoxContainer/Control/MarginContainer/ColorRect/PortraitTexture

@onready var button: Button = $Button


func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)

func has_member() -> bool:
	return _member != null

func needs_healing() -> bool:
	return _member != null and _member.current_health < _member.max_health

func set_highlight(enabled: bool) -> void:
	if enabled:
		modulate = ProjectColors.CHARACTER_HIGHLIGHT
	else:
		modulate = Color.WHITE

func set_member(member: PartyMember) -> void:
	_member = member
	if not member:
		name_label.text = ""
		level_label.text = ""
		class_label.text = ""
		race_label.text = ""
		portrait_texture.texture = null
		_update_hp_bar(0, 0)
		_update_xp_bar(0, 1, false)
		return
	name_label.text = member.member_name
	level_label.text = str(member.level)
	class_label.text = member.class_resource.name if member.class_resource else ""
	race_label.text = member.race.race_name if member.race else ""
	portrait_texture.texture = member.get_portrait()
	_update_hp_bar(member.current_health, member.max_health)
	_update_xp_bar(member.experience, member.experience_to_next_level, false)

## Called after XP is awarded to animate the bar filling up.
func refresh_xp() -> void:
	if not _member:
		return
	level_label.text = str(_member.level)
	_update_xp_bar(_member.experience, _member.experience_to_next_level, true)

func _update_hp_bar(current: int, maximum: int) -> void:
	hp_progress_bar.set_health(current, maximum)

func _update_xp_bar(current: int, to_next: int, animated: bool) -> void:
	xp_progress_bar.set_experience(current, to_next, animated)

func _on_button_pressed() -> void:
	if _member:
		character_clicked.emit(_member)
