extends Control
class_name PlayerPartyPanel

@onready var character_info_panel_1: CharacterCombatInformationPanel = $CharacterCombatInformationPanel
@onready var character_info_panel_2: CharacterCombatInformationPanel = $CharacterCombatInformationPanel2
@onready var character_info_panel_3: CharacterCombatInformationPanel = $CharacterCombatInformationPanel3


func get_panel(slot_index: int) -> CharacterCombatInformationPanel:
	match slot_index:
		0:
			return character_info_panel_1
		1:
			return character_info_panel_2
		2:
			return character_info_panel_3
	return null


## Show one panel per live party slot (max 3); unused slots hidden and lightly cleared.
func apply_party_panel_count(count: int) -> void:
	count = clampi(count, 0, 3)
	for i in range(3):
		var p := get_panel(i)
		if p == null:
			continue
		var used: bool = i < count
		p.visible = used
		if not used:
			p.update_display("", 0, 1, 0, 1)
			p.modulate = Color(1.0, 1.0, 1.0, 1.0)
			p.reset_portrait_frame_modulate()
