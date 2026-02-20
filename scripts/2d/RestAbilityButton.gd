extends PanelContainer

## RestAbilityButton - UI for a single rest ability
## Instantiated per character rest ability; shows name, availability, and handles click

signal ability_pressed(rest_ability: RestAbility)

var rest_ability: RestAbility = null

@onready var _button: Button = $Button

func _ready():
	if _button:
		_button.pressed.connect(_on_button_pressed)

## Initialize with rest ability data and current duration
## duration: 0=quick, 1=medium, 2=long
func setup(ability: RestAbility, current_duration: int) -> void:
	rest_ability = ability
	if not rest_ability:
		visible = false
		return
	visible = true
	if _button:
		_button.text = rest_ability.ability_name if rest_ability.ability_name else "Rest Ability"
		_button.disabled = not rest_ability.is_available_for_duration(current_duration)
		_button.tooltip_text = rest_ability.description

func _on_button_pressed() -> void:
	if rest_ability:
		ability_pressed.emit(rest_ability)
		# Placeholder: no effect yet; ready for future functionality
