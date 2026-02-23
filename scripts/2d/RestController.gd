extends Control
class_name RestController

## RestController - Manages the rest screen and rest mechanics
## Handles rest duration selection, benefits/risks display, rest abilities, and party healing

# Signals
signal rest_complete()
signal ambush_triggered()

# Rest duration tiers: 0=quick, 1=medium, 2=long
enum RestDuration {
	QUICK,
	MEDIUM,
	LONG
}

# Per-duration config: heal percent (0-100), ambush chance (0-100)
# Longer rest = more healing but higher ambush risk (more time for enemies to find you)
const NIGHTTIME_AMBUSH_ENCOUNTER_ID: String = "nighttime_ambush"

const REST_CONFIG: Dictionary = {
	RestDuration.QUICK: {"heal_percent": 25, "ambush_chance": 10, "time_units": 1, "camping_supplies_cost": 1},
	RestDuration.MEDIUM: {"heal_percent": 50, "ambush_chance": 20, "time_units": 2, "camping_supplies_cost": 2},
	RestDuration.LONG: {"heal_percent": 100, "ambush_chance": 30, "time_units": 3, "camping_supplies_cost": 3}
}

const CAMPING_SUPPLIES_ITEM_ID: String = "camping_supplies"

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
var _safe_rest: bool = false  # True when resting at Inn (town) - no ambush chance

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
	_update_rest_button_state()
	_refresh_ability_buttons()

func _update_labels() -> void:
	var config = REST_CONFIG.get(current_duration, REST_CONFIG[RestDuration.MEDIUM])
	var heal_pct = config.get("heal_percent", 50)
	var ambush_pct: int = 0 if _safe_rest else config.get("ambush_chance", 20)
	var supplies_cost: int = config.get("camping_supplies_cost", 2)
	if rest_benefits_label:
		var cost_text: String = "No supplies (Inn)" if _safe_rest else "%d camping supplies" % supplies_cost
		rest_benefits_label.text = "Healing: %d%% of max HP\nCost: %s" % [heal_pct, cost_text]
	if rest_risks_label:
		rest_risks_label.text = "Ambush risk: %d%%" % ambush_pct
	_update_rest_button_state()

func _get_party_camping_supplies() -> int:
	var total := 0
	for m in _party_members:
		if m is PartyMember:
			total += m.get_item_count(CAMPING_SUPPLIES_ITEM_ID)
	return total

func _update_rest_button_state() -> void:
	if not rest_button:
		return
	var config = REST_CONFIG.get(current_duration, REST_CONFIG[RestDuration.MEDIUM])
	var supplies_cost: int = 0 if _safe_rest else config.get("camping_supplies_cost", 2)
	rest_button.disabled = _get_party_camping_supplies() < supplies_cost

func _spend_camping_supplies(amount: int) -> void:
	var remaining := amount
	for m in _party_members:
		if remaining <= 0:
			break
		if m is PartyMember:
			var has: int = m.get_item_count(CAMPING_SUPPLIES_ITEM_ID)
			var to_take: int = mini(has, remaining)
			if to_take > 0:
				m.remove_item(CAMPING_SUPPLIES_ITEM_ID, to_take)
				remaining -= to_take

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

func _apply_supplies_based_duration_gating() -> void:
	if _safe_rest:
		# Inn rest: all options available, Long chosen by default
		quick_rest_button.disabled = false
		medium_rest_button.disabled = false
		long_rest_button.disabled = false
		_set_duration(RestDuration.LONG)
		return
	var supplies := _get_party_camping_supplies()
	var quick_cost: int = REST_CONFIG[RestDuration.QUICK].get("camping_supplies_cost", 1)
	var medium_cost: int = REST_CONFIG[RestDuration.MEDIUM].get("camping_supplies_cost", 2)
	var long_cost: int = REST_CONFIG[RestDuration.LONG].get("camping_supplies_cost", 3)
	quick_rest_button.disabled = supplies < quick_cost
	medium_rest_button.disabled = supplies < medium_cost
	long_rest_button.disabled = supplies < long_cost
	# Default to highest affordable tier: 1 supply -> Quick, 2 -> Medium, 3+ -> Long
	if supplies >= long_cost:
		_set_duration(RestDuration.LONG)
	elif supplies >= medium_cost:
		_set_duration(RestDuration.MEDIUM)
	else:
		_set_duration(RestDuration.QUICK)

func start_rest(party_members: Array = [], safe_rest: bool = false) -> void:
	if is_resting:
		return
	_party_members = party_members
	_safe_rest = safe_rest
	is_resting = true
	visible = true
	_apply_supplies_based_duration_gating()
	_populate_ability_panels()
	_update_rest_button_state()
	print("RestController: Rest started (duration: %s)" % RestDuration.keys()[current_duration])

func _on_rest_button_pressed() -> void:
	complete_rest()

func complete_rest() -> void:
	if not is_resting:
		print("[Rest Ambush DEBUG] complete_rest called but not resting - SKIP")
		return
	var config = REST_CONFIG.get(current_duration, REST_CONFIG[RestDuration.MEDIUM])
	var supplies_cost: int = 0 if _safe_rest else config.get("camping_supplies_cost", 2)
	var party_supplies: int = _get_party_camping_supplies()
	if party_supplies < supplies_cost:
		print("RestController: Not enough camping supplies (have %d, need %d)" % [party_supplies, supplies_cost])
		return
	if supplies_cost > 0:
		_spend_camping_supplies(supplies_cost)
	var ambush_chance: int = 0 if _safe_rest else config.get("ambush_chance", 20)
	var roll: float = randf() * 100.0
	
	# Debug: ambush check
	var duration_names := ["QUICK", "MEDIUM", "LONG"]
	var duration_name: String = duration_names[current_duration] if current_duration >= 0 and current_duration < duration_names.size() else "UNKNOWN"
	print("[Rest Ambush DEBUG] --- Ambush roll ---")
	print("[Rest Ambush DEBUG]   Duration: %s | ambush_chance: %d%% (%s)" % [duration_name, ambush_chance, "Inn (safe)" if _safe_rest else "wilderness"])
	print("[Rest Ambush DEBUG]   Roll: %.2f (0-100)" % roll)
	if roll < ambush_chance:
		print("[Rest Ambush DEBUG]   Result: AMBUSH (roll %.2f < threshold %d) - FAILED" % [roll, ambush_chance])
		_trigger_nighttime_ambush()
		return
	else:
		print("[Rest Ambush DEBUG]   Result: SAFE (roll %.2f >= threshold %d) - PASSED" % [roll, ambush_chance])
	# Advance world time based on rest duration
	var time_units: int = config.get("time_units", 2)
	if TimeManager and time_units > 0:
		TimeManager.advance_time_from_rest(float(time_units))
	var heal_pct = config.get("heal_percent", 50)
	for member in _party_members:
		var heal_amount = int(member.max_health * heal_pct / 100.0)
		member.heal(heal_amount)
	is_resting = false
	visible = false
	rest_complete.emit()
	print("[Rest Ambush DEBUG] Rest completed safely (healed %d%% HP)" % heal_pct)

func _trigger_nighttime_ambush() -> void:
	print("[Rest Ambush DEBUG] --- Triggering nighttime ambush ---")
	# Advance world time based on rest duration (player rested before being ambushed)
	var config = REST_CONFIG.get(current_duration, REST_CONFIG[RestDuration.MEDIUM])
	var time_units: int = config.get("time_units", 2)
	if TimeManager and time_units > 0:
		TimeManager.advance_time_from_rest(float(time_units))
	ambush_triggered.emit()
	is_resting = false
	visible = false
	var encounter_path := "res://resources/encounters/%s.tres" % NIGHTTIME_AMBUSH_ENCOUNTER_ID
	print("[Rest Ambush DEBUG]   Check: Load encounter from '%s'" % encounter_path)
	var encounter = load(encounter_path) as CombatEncounter
	if not encounter:
		print("[Rest Ambush DEBUG]   Result: FAILED - could not load encounter")
		push_error("RestController: Could not load encounter: " + encounter_path)
		rest_complete.emit()
		return
	print("[Rest Ambush DEBUG]   Result: PASSED - encounter loaded")
	var root = get_tree().root
	var main: Node = null
	print("[Rest Ambush DEBUG]   Check: Find Main node in scene tree")
	for child in root.get_children():
		if child.name == "Main" or child.is_in_group("main"):
			main = child
			break
	if not main:
		print("[Rest Ambush DEBUG]   Result: FAILED - Main node not found")
		push_error("RestController: Could not find Main for ambush")
		rest_complete.emit()
		return
	print("[Rest Ambush DEBUG]   Result: PASSED - Main node found")
	print("[Rest Ambush DEBUG]   Spawning CombatScene and starting ambush combat...")
	var combat_scene = load("res://scenes/combat/CombatScene.tscn").instantiate()
	main.ui_controller.add_child(combat_scene)
	call_deferred("_start_ambush_combat", encounter, main)

func _start_ambush_combat(encounter: Resource, main: Node) -> void:
	CombatController.start_combat_from_encounter(encounter, main.current_party_members)
	print("[Rest Ambush DEBUG] Ambush combat started - all checks PASSED")

func cancel_rest() -> void:
	is_resting = false
	visible = false
	print("RestController: Rest cancelled")
