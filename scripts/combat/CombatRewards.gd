extends Control

## Post-combat rewards panel: gold, XP, per-member progress, continue button

signal continue_pressed

@onready var gold_gained_label: Label = $VBoxContainer/PanelNinePatchRect2/HBoxContainer/GoldGainedLabel
@onready var exp_gained_label: Label = $VBoxContainer/PanelNinePatchRect5/HBoxContainer/ExpGainedLabel
@onready var character_rewards_1: CharacterRewardsDisplay = $VBoxContainer/PanelNinePatchRect4/VBoxContainer/PartyRewardsPanelContainer/VBoxContainer/CharacterRewards
@onready var character_rewards_2: CharacterRewardsDisplay = $VBoxContainer/PanelNinePatchRect4/VBoxContainer/PartyRewardsPanelContainer/VBoxContainer/CharacterRewards2
@onready var character_rewards_3: CharacterRewardsDisplay = $VBoxContainer/PanelNinePatchRect4/VBoxContainer/PartyRewardsPanelContainer/VBoxContainer/CharacterRewards3
@onready var continue_button: Button = $VBoxContainer/PanelNinePatchRect3/HBoxContainer/PanelNinePatchRect2/VBoxContainer/ContinueButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)

func show_rewards(rewards: Dictionary, party_members: Array):
	gold_gained_label.text = str(rewards.get("gold", 0))
	exp_gained_label.text = str(rewards.get("xp", 0))
	var xp_gained: int = rewards.get("xp", 0)
	var displays = [character_rewards_1, character_rewards_2, character_rewards_3]
	for i in range(displays.size()):
		if i < party_members.size():
			displays[i].set_display(party_members[i], xp_gained)
		else:
			displays[i].set_display(null, 0)

func _on_continue_pressed():
	continue_pressed.emit()
