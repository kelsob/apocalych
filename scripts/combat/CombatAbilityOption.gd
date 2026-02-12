extends Button

## CombatAbilityOption - UI button for selecting an ability in combat
## Shows ability name, AP cost, and handles click interactions

# Node references
@onready var selection_icon: TextureRect = $HBoxContainer/SelectionIcon
@onready var ability_name_label: Label = $HBoxContainer/AbilityNameLabel
@onready var ap_cost_label: Label = $HBoxContainer/APCostLabel

# Data
var ability: Ability = null

signal ability_selected(ability: Ability)

func _ready():
	# Connect focus and hover signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	
	# Hide icon by default
	if selection_icon:
		selection_icon.visible = false

## Initialize the ability option with data
func setup(ability_data: Ability):
	ability = ability_data
	update_display()

## Update the display with current ability data
func update_display():
	if not ability:
		return
	
	if ability_name_label:
		ability_name_label.text = ability.ability_name
	
	if ap_cost_label:
		ap_cost_label.text = "%d AP" % ability.get_modified_ap_cost()

## Set whether this button is enabled/disabled
func set_ability_enabled(enabled: bool):
	disabled = not enabled
	
	# Visual feedback for disabled state
	if disabled:
		modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		modulate = Color.WHITE

## Show selection icon when hovered
func _on_mouse_entered():
	if selection_icon and not disabled:
		selection_icon.visible = true

## Hide selection icon when not hovered
func _on_mouse_exited():
	if selection_icon and not has_focus():
		selection_icon.visible = false

## Show selection icon when focused
func _on_focus_entered():
	if selection_icon:
		selection_icon.visible = true

## Hide selection icon when focus lost
func _on_focus_exited():
	if selection_icon:
		selection_icon.visible = false

## Called when button is pressed
func _on_pressed():
	if ability:
		ability_selected.emit(ability)
