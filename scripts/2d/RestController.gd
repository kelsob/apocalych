extends Control
class_name RestController

## RestController - Manages the rest screen and rest mechanics
## Handles rest duration selection, benefits/risks display, rest abilities, and party healing

# Signals
signal rest_complete()

# Rest duration tiers: 0=quick, 1=medium, 2=long
enum RestDuration {
	QUICK,
	MEDIUM,
	LONG
}

# Per-duration config: heal percent (0-100), ambush chance (0-100)
# Longer rest = more healing but higher ambush risk (more time for enemies to find you)
const REST_CONFIG: Dictionary = {
	RestDuration.QUICK: {"heal_percent": 25, "ambush_chance": 10},
	RestDuration.MEDIUM: {"heal_percent": 50, "ambush_chance": 20},
	RestDuration.LONG: {"heal_percent": 100, "ambush_chance": 30}
}

# Node references
@onready var rest_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/RestButton
@onready var character_1_rest_abilities_panel: HBoxContainer = $VBoxContainer/HBoxContainer2/Character1RestAbilities
@onready var character_2_rest_abilities_panel: HBoxContainer = $VBoxContainer/HBoxContainer2/Character2RestAbilities
@onready var character_3_rest_abilities_panel: HBoxContainer = $VBoxContainer/HBoxContainer2/Character3RestAbilities
@onready var rest_benefits_label: Label = $VBoxContainer/HBoxContainer/MarginContainer/RestBenefitsLabel
@onready var rest_risks_label: Label = $VBoxContainer/HBoxContainer/MarginContainer2/RestRisksLabel
@onready var quick_rest_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/QuickRestButton
@onready var medium_rest_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/MediumRestButton
@onready var long_rest_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/LongRestButton

var rest_ability_button_scene: PackedScene = preload("res://scenes/2d/RestAbilityButton.tscn")

var is_resting: bool = false
var current_duration: int = RestDuration.MEDIUM
var _party_members: Array[PartyMember] = []

func _ready():
	visible = false
	_connect_signals()
	_set_duration(RestDuration.MEDIUM)

func _connect_signals() -> void:
	if rest_button:
		rest_button.pressed.connect(_on_rest_button_pressed)
	if quick_rest_button:
		quick_rest_button.pressed.connect(_on_quick_rest_pressed)
	if medium_rest_button:
		medium_rest_button.pressed.connect(_on_medium_rest_pressed)
	if long_rest_button:
		long_rest_button.pressed.connect(_on_long_rest_pressed)

func _on_quick_rest_pressed() -> void:
	if quick_rest_button.button_pressed:
		_set_duration(RestDuration.QUICK)

func _on_medium_rest_pressed() -> void:
	if medium_rest_button.button_pressed:
		_set_duration(RestDuration.MEDIUM)

func _on_long_rest_pressed() -> void:
	if long_rest_button.button_pressed:
		_set_duration(RestDuration.LONG)

func _set_duration(duration: int) -> void:
	current_duration = duration
	# Exclusive toggle: only the selected one stays pressed
	quick_rest_button.button_pressed = (duration == RestDuration.QUICK)
	medium_rest_button.button_pressed = (duration == RestDuration.MEDIUM)
	long_rest_button.button_pressed = (duration == RestDuration.LONG)
	_update_labels()
	_refresh_ability_buttons()

func _update_labels() -> void:
	var config = REST_CONFIG.get(current_duration, REST_CONFIG[RestDuration.MEDIUM])
	var heal_pct = config.get("heal_percent", 50)
	var ambush_pct = config.get("ambush_chance", 20)
	if rest_benefits_label:
		rest_benefits_label.text = "Healing: %d%% of max HP" % heal_pct
	if rest_risks_label:
		rest_risks_label.text = "Ambush risk: %d%%" % ambush_pct

func _get_ability_panels() -> Array[HBoxContainer]:
	return [character_1_rest_abilities_panel, character_2_rest_abilities_panel, character_3_rest_abilities_panel]

func _clear_ability_panels() -> void:
	for panel in _get_ability_panels():
		if panel:
			for c in panel.get_children():
				c.queue_free()

func _populate_ability_panels() -> void:
	_clear_ability_panels()
	var panels = _get_ability_panels()
	for i in range(mini(_party_members.size(), panels.size())):
		var member: PartyMember = _party_members[i]
		var panel: HBoxContainer = panels[i]
		if not panel:
			continue
		var abilities = member.get_rest_abilities()
		for ability in abilities:
			var btn = rest_ability_button_scene.instantiate()
			if btn.has_method("setup"):
				btn.setup(ability, current_duration)
			panel.add_child(btn)

func _refresh_ability_buttons() -> void:
	var panels = _get_ability_panels()
	for i in range(mini(_party_members.size(), panels.size())):
		var panel: HBoxContainer = panels[i]
		if not panel:
			continue
		for c in panel.get_children():
			if c.has_method("setup") and c.get("rest_ability"):
				c.setup(c.rest_ability, current_duration)

func start_rest(party_members: Array = []) -> void:
	if is_resting:
		return
	_party_members = party_members
	is_resting = true
	visible = true
	_set_duration(RestDuration.MEDIUM)
	_populate_ability_panels()
	print("RestController: Rest started (duration: %s)" % RestDuration.keys()[current_duration])

func _on_rest_button_pressed() -> void:
	complete_rest()

func complete_rest() -> void:
	if not is_resting:
		return
	var config = REST_CONFIG.get(current_duration, REST_CONFIG[RestDuration.MEDIUM])
	var heal_pct = config.get("heal_percent", 50)
	for member in _party_members:
		var heal_amount = int(member.max_health * heal_pct / 100.0)
		member.heal(heal_amount)
	# TODO: time passage when time system exists
	# TODO: ambush roll when ambush system exists
	is_resting = false
	visible = false
	rest_complete.emit()
	print("RestController: Rest completed (healed %d%% HP)" % heal_pct)

func cancel_rest() -> void:
	is_resting = false
	visible = false
	print("RestController: Rest cancelled")
