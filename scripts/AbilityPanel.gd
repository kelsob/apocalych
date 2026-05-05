extends Control
@onready var ability_list_container: VBoxContainer = $PanelContainer/MarginContainer/AbilityListContainer
@onready var ability_description_panel: PanelContainer = $AbilityDescriptionPanel

const ABILITY_OPTION_SCENE := preload("res://scenes/combat/CombatAbilityOption.tscn")

var current_combatant: CombatantData = null

signal ability_selected(ability: Ability)


func _ready() -> void:
	hide_panel()


func show_for_combatant(combatant: CombatantData) -> void:
	if combatant == null:
		hide_panel()
		return
	current_combatant = combatant
	visible = true
	_rebuild_ability_buttons()


func hide_panel() -> void:
	current_combatant = null
	_clear_ability_buttons()
	visible = false
	if ability_description_panel and ability_description_panel.has_method("clear_display"):
		ability_description_panel.call("clear_display")


func refresh_current_combatant() -> void:
	if not visible or current_combatant == null:
		return
	_rebuild_ability_buttons()


func _clear_ability_buttons() -> void:
	for child in ability_list_container.get_children():
		child.queue_free()


func _rebuild_ability_buttons() -> void:
	_clear_ability_buttons()
	if current_combatant == null:
		return
	var first_enabled_ability: Ability = null
	for ability in current_combatant.abilities:
		if ability == null:
			continue
		var option := ABILITY_OPTION_SCENE.instantiate()
		if option == null:
			continue
		ability_list_container.add_child(option)
		option.setup(ability)
		var can_use := _is_ability_currently_usable(ability)
		option.set_ability_enabled(can_use)
		option.ability_selected.connect(_on_option_selected)
		option.mouse_entered.connect(_on_option_hovered.bind(ability))
		option.focus_entered.connect(_on_option_hovered.bind(ability))
		if can_use and first_enabled_ability == null:
			first_enabled_ability = ability
	if first_enabled_ability != null and ability_description_panel and ability_description_panel.has_method("show_ability"):
		ability_description_panel.call("show_ability", first_enabled_ability)
	elif ability_description_panel and ability_description_panel.has_method("clear_display"):
		ability_description_panel.call("clear_display")


func _is_ability_currently_usable(ability: Ability) -> bool:
	if current_combatant == null or ability == null:
		return false
	if not current_combatant.can_cast_ability_this_turn(ability):
		return false
	if current_combatant.combatant_stats == null:
		return false
	if current_combatant.combatant_stats.current_ap < ability.get_modified_ap_cost():
		return false
	if ability.requires_target:
		var valid_targets := CombatController.get_valid_targets(current_combatant, ability)
		if valid_targets.is_empty():
			return false
	return true


func _on_option_selected(ability: Ability) -> void:
	if ability == null:
		return
	if ability_description_panel and ability_description_panel.has_method("show_ability"):
		ability_description_panel.call("show_ability", ability)
	ability_selected.emit(ability)
	call_deferred("refresh_current_combatant")


func _on_option_hovered(ability: Ability) -> void:
	if ability == null:
		return
	if ability_description_panel and ability_description_panel.has_method("show_ability"):
		ability_description_panel.call("show_ability", ability)
