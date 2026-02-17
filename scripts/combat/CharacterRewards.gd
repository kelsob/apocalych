extends HBoxContainer
class_name CharacterRewardsDisplay

## One row of rewards for a party member: name, XP progress bar, XP gained label

@onready var character_texture_rect : TextureRect = $MarginContainer/HBoxContainer/CharacterTextureRect
@onready var character_name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/CharacterNameLabel
@onready var level_label : Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel
@onready var race_label : Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/RaceLabel
@onready var class_label : Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var experience_progress_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer2/ExperienceProgressBar
@onready var experience_gain_label: Label = $MarginContainer/HBoxContainer/VBoxContainer2/ExperienceToLevelLabel

func set_display(member: PartyMember, xp_gained: int):
	if member == null:
		visible = false
		return
	visible = true
	character_name_label.text = member.member_name
	level_label.text = "Level %d" % member.level
	race_label.text = member.race.race_name if member.race else ""
	class_label.text = member.class_resource.name if member.class_resource else ""
	experience_progress_bar.min_value = 0
	experience_progress_bar.max_value = member.experience_to_next_level
	experience_progress_bar.value = member.experience
	experience_gain_label.text = "%d / %d (+%d XP)" % [member.experience, member.experience_to_next_level, xp_gained]
	# Portrait: set when PartyMember has a portrait texture; leave empty for now
	character_texture_rect.texture = null
