extends MarginContainer

@onready var name_label: Label = $VBoxContainer/HBoxContainer/NameLabel
@onready var ap_label: Label = $VBoxContainer/HBoxContainer/HBoxContainer/APLabel
@onready var ap_max_label: Label = $VBoxContainer/HBoxContainer/HBoxContainer/APMaxLabel
@onready var health_label: Label = $VBoxContainer/HBoxContainer/HBoxContainer2/HealthLabel
@onready var health_max_label: Label = $VBoxContainer/HBoxContainer/HBoxContainer2/HealthMaxLabel

## Update display with current combatant stats
func update_display(combatant_name: String, current_hp: int, max_hp: int, current_ap: int, max_ap: int):
	if name_label:
		name_label.text = combatant_name
	
	if health_label:
		health_label.text = str(current_hp)
	
	if health_max_label:
		health_max_label.text = str(max_hp)
	
	if ap_label:
		ap_label.text = str(current_ap)
	
	if ap_max_label:
		ap_max_label.text = str(max_ap)
