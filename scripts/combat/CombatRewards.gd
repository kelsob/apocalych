extends Control

## Post-combat rewards panel: gold, XP, per-member progress, continue button
## Shows 0 initially, then after a delay counts up to actual values (party not rewarded until Continue).

signal continue_pressed

@export var count_up_delay: float = 2.0
@export var count_up_duration: float = 1.2

@onready var gold_gained_label: Label = $MarginContainer/VBoxContainer/PanelNinePatchRect2/MarginContainer/HBoxContainer/GoldGainedLabel
@onready var exp_gained_label: Label = $MarginContainer/VBoxContainer/PanelNinePatchRect5/MarginContainer/HBoxContainer/ExpGainedLabel
@onready var character_rewards_1: CharacterRewardsDisplay = $MarginContainer/VBoxContainer/PanelNinePatchRect4/MarginContainer/PartyRewardsContainer/CharacterRewards
@onready var character_rewards_2: CharacterRewardsDisplay = $MarginContainer/VBoxContainer/PanelNinePatchRect4/MarginContainer/PartyRewardsContainer/CharacterRewards2
@onready var character_rewards_3: CharacterRewardsDisplay = $MarginContainer/VBoxContainer/PanelNinePatchRect4/MarginContainer/PartyRewardsContainer/CharacterRewards3
@onready var continue_button: Button = $MarginContainer/VBoxContainer/PanelNinePatchRect3/MarginContainer/HBoxContainer/PanelNinePatchRect2/MarginContainer/VBoxContainer/ContinueButton

var _target_gold: int = 0
var _target_xp: int = 0
var _party_members: Array = []
var _displayed_gold: int = 0
var _displayed_xp: int = 0
var _count_up_elapsed: float = 0.0
var _phase: String = ""  # "" | "delay" | "counting" | "done"
var _rewards_applied: bool = false
var _rewards: Dictionary = {}
var _victory: bool = false
var _main: Node = null

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)

func show_rewards(rewards: Dictionary, party_members: Array, victory: bool = false, main_node: Node = null):
	_rewards = rewards
	_victory = victory
	_main = main_node
	_rewards_applied = false
	_target_gold = rewards.get("gold", 0)
	_target_xp = rewards.get("xp", 0)
	_party_members = party_members
	_displayed_gold = 0
	_displayed_xp = 0
	_count_up_elapsed = 0.0
	_phase = "delay"

	gold_gained_label.text = "0"
	exp_gained_label.text = "0"
	var displays = [character_rewards_1, character_rewards_2, character_rewards_3]
	for i in range(displays.size()):
		if i < party_members.size():
			displays[i].set_display_simulated(party_members[i], 0)
		else:
			displays[i].set_display(null, 0)

func _process(delta: float):
	if _phase == "":
		return
	if _phase == "delay":
		_count_up_elapsed += delta
		if _count_up_elapsed >= count_up_delay:
			_phase = "counting"
			_count_up_elapsed = 0.0
		return

	if _phase == "counting":
		_count_up_elapsed += delta
		var t := clampf(_count_up_elapsed / count_up_duration, 0.0, 1.0)
		_displayed_gold = int(lerpf(0, _target_gold, t))
		_displayed_xp = int(lerpf(0, _target_xp, t))

		gold_gained_label.text = str(_displayed_gold)
		exp_gained_label.text = str(_displayed_xp)

		var displays = [character_rewards_1, character_rewards_2, character_rewards_3]
		for i in range(displays.size()):
			if i < _party_members.size():
				displays[i].set_display_simulated(_party_members[i], _displayed_xp)

		if t >= 1.0:
			_phase = "done"
			set_process(false)

func _on_continue_pressed():
	var was_already_done := _phase == "done"
	if _phase != "done":
		_complete_animation()
	if not _rewards_applied and _main and _main.has_method("apply_combat_rewards"):
		_main.apply_combat_rewards(_victory, _rewards)
		_rewards_applied = true
	if was_already_done:
		continue_pressed.emit()

func _complete_animation():
	_displayed_gold = _target_gold
	_displayed_xp = _target_xp
	_phase = "done"
	set_process(false)

	gold_gained_label.text = str(_displayed_gold)
	exp_gained_label.text = str(_displayed_xp)
	var displays = [character_rewards_1, character_rewards_2, character_rewards_3]
	for i in range(displays.size()):
		if i < _party_members.size():
			displays[i].set_display_simulated(_party_members[i], _displayed_xp)
