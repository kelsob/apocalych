extends PanelContainer

@onready var name_label: Label = $VBoxContainer/HBoxContainer/NameLabel
@onready var ap_label: Label = $VBoxContainer/HBoxContainer/APLabel
@onready var health_label: Label = $VBoxContainer/HBoxContainer/HealthLabel

## Update display with current combatant stats
func update_display(combatant_name: String, current_hp: int, max_hp: int, current_ap: int, max_ap: int):
	name_label.text = combatant_name
	health_label.text = "HP: %d/%d" % [current_hp, max_hp]
	ap_label.text = "AP: %d/%d" % [current_ap, max_ap]
