extends HBoxContainer
class_name CharacterRewardsDisplay

## One row of rewards for a party member: name, XP progress bar, XP gained label

@onready var character_texture_rect : TextureRect = $MarginContainer/HBoxContainer/CharacterTextureRect
@onready var character_name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/CharacterNameLabel
@onready var level_label : Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel
@onready var race_label : Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/RaceLabel
@onready var class_label : Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ClassLabel
@onready var experience_progress_bar: XPBar = $MarginContainer/HBoxContainer/VBoxContainer2/ExpBar
@onready var experience_gain_label: Label = $MarginContainer/HBoxContainer/VBoxContainer2/ExperienceToLevelLabel

## Simulate adding XP without mutating member. Returns {exp, exp_to_next, level}.
static func _simulate_exp_add(exp: int, exp_to_next: int, level: int, amount: int) -> Dictionary:
	var e := exp
	var etn := exp_to_next
	var lvl := level
	e += amount
	while e >= etn:
		e -= etn
		lvl += 1
		etn = int(100 * pow(1.5, lvl - 1))
	return {"exp": e, "exp_to_next": etn, "level": lvl}

func set_display(member: PartyMember, xp_gained: int):
	if member == null:
		visible = false
		return
	_set_display_internal(member, xp_gained, member.experience, member.experience_to_next_level, member.level)

## Update display with simulated XP (for count-up animation). displayed_xp is the amount to simulate adding.
func set_display_simulated(member: PartyMember, displayed_xp: int):
	if member == null:
		visible = false
		return
	var sim = _simulate_exp_add(member.experience, member.experience_to_next_level, member.level, displayed_xp)
	_set_display_internal(member, displayed_xp, sim.exp, sim.exp_to_next, sim.level)

func _set_display_internal(member: PartyMember, xp_gained: int, exp: int, exp_to_next: int, level: int):
	if member == null:
		visible = false
		return
	visible = true
	character_name_label.text = member.member_name
	level_label.text = "Level %d" % level
	race_label.text = member.race.race_name if member.race else ""
	class_label.text = member.class_resource.name if member.class_resource else ""
	experience_progress_bar.set_experience(exp, exp_to_next, false)
	experience_gain_label.text = "%d / %d (+%d XP)" % [exp, exp_to_next, xp_gained]
	character_texture_rect.texture = member.get_combat_portrait()
