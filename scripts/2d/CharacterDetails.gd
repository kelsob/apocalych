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
	level_label.text = "Lvl. " + str(member.level)
	class_label.text = member.class_resource.name if member.class_resource else ""
	race_label.text = member.race.race_name if member.race else ""
	portrait_texture.texture = member.get_portrait()
	_update_hp_bar(member.current_health, member.max_health)
	_update_xp_bar(member.experience, member.experience_to_next_level, false)

## Called after XP is awarded. Plays through fill → level-up → reset → fill sequence.
## Runs as a fire-and-forget coroutine when called without await.
func refresh_xp() -> void:
	if not _member:
		return

	var steps: Array = EventManager._xp_animation_data.get(_member, [])
	EventManager._xp_animation_data.erase(_member)

	if steps.size() <= 1:
		# No level-up (or no data): simple animated update to current member state
		level_label.text = "Lvl. " + str(_member.level)
		xp_progress_bar.set_experience(_member.experience, _member.experience_to_next_level, true)
		return

	# Level-up(s) occurred — animate through each step sequentially.
	# Step 1: fill bar to max of the initial level
	var tween := xp_progress_bar.set_experience(
		steps[0].experience_to_next_level,
		steps[0].experience_to_next_level,
		true
	)
	if tween:
		await tween.finished

	# Step 2..n: each represents a new level reached
	for i in range(1, steps.size()):
		var step: Dictionary = steps[i]
		level_label.text = "Lvl. " + str(step.level)
		# Instantly reset bar to 0 with the new level's threshold
		xp_progress_bar.set_experience(0, step.experience_to_next_level, false)
		if i < steps.size() - 1:
			# More levels to gain: fill to max before looping
			var t := xp_progress_bar.set_experience(step.experience_to_next_level, step.experience_to_next_level, true)
			if t:
				await t.finished
		else:
			# Final level: animate to resting XP position
			xp_progress_bar.set_experience(step.experience, step.experience_to_next_level, true)

func _update_hp_bar(current: int, maximum: int) -> void:
	hp_progress_bar.set_health(current, maximum)

func _update_xp_bar(current: int, to_next: int, animated: bool) -> void:
	xp_progress_bar.set_experience(current, to_next, animated)

func _on_button_pressed() -> void:
	if _member:
		character_clicked.emit(_member)
