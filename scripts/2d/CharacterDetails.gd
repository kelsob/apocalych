extends Control

signal character_clicked(member: PartyMember)

var _member: PartyMember = null

@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var class_label: Label = $HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var race_label: Label = $HBoxContainer/VBoxContainer/HBoxContainer/RaceLabel
@onready var level_label: Label = $HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

@onready var hp_progress_bar: ProgressBar = $HBoxContainer/VBoxContainer/HPProgressBar

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
		_update_hp_bar(0, 0)
		return
	name_label.text = member.member_name
	level_label.text = str(member.level)
	class_label.text = member.class_resource.name if member.class_resource else ""
	race_label.text = member.race.race_name if member.race else ""
	_update_hp_bar(member.current_health, member.max_health)


func _update_hp_bar(current: int, maximum: int) -> void:
	if hp_progress_bar:
		hp_progress_bar.min_value = 0
		hp_progress_bar.max_value = maximum if maximum > 0 else 1
		hp_progress_bar.value = current

func _on_button_pressed() -> void:
	if _member:
		character_clicked.emit(_member)
