extends Control
class_name CharacterCombatInformationPanel

@onready var name_label: Label = $Control/NameLabel
@onready var ap_label: Label = $Control/HBoxContainer/APLabel
@onready var ap_max_label: Label = $Control/HBoxContainer/APMaxLabel
@onready var health_label: Label = $Control/HBoxContainer2/HealthLabel
@onready var health_max_label: Label = $Control/HBoxContainer2/HealthMaxLabel
@onready var health_progress_bar: HPBar = $Control/HPBar
@onready var portrait_texture: TextureRect = $CharacterPortraitFrame/CharacterPortrait

## Update display with current combatant stats. [param combat_portrait] defaults to map/event portrait from [method HeroCharacter.get_portrait]; [code]null[/code] hides the portrait.
func update_display(combatant_name: String, current_hp: int, max_hp: int, current_ap: int, max_ap: int, combat_portrait: Texture2D = null) -> void:
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
	
	if health_progress_bar:
		health_progress_bar.set_health(current_hp, max_hp)
	
	if portrait_texture:
		portrait_texture.texture = combat_portrait
		portrait_texture.visible = combat_portrait != null
