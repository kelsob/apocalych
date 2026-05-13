extends Control
@onready var ability_list_container: VBoxContainer = $AbilityListPanel/MarginContainer/AbilityListContainer
@onready var ability_description_panel: MarginContainer = $AbilityDescriptionPanel

const ABILITY_OPTION_SCENE := preload("res://scenes/combat/CombatAbilityOption.tscn")

var current_combatant: CombatantData = null
var _ability_options: Array = []
var _highlighted_option_index: int = -1
var _ability_input_enabled: bool = true

signal ability_selected(ability: Ability)


func _ready() -> void:
	hide_panel()
	set_process_unhandled_input(true)


func show_for_combatant(combatant: CombatantData) -> void:
	if combatant == null:
		hide_panel()
		return
	current_combatant = combatant
	visible = true
	_ability_input_enabled = true
	_rebuild_ability_buttons()


func hide_panel() -> void:
	current_combatant = null
	_clear_ability_buttons()
	_highlighted_option_index = -1
	_ability_input_enabled = true
	visible = false
	if ability_description_panel and ability_description_panel.has_method("clear_display"):
		ability_description_panel.call("clear_display")


func refresh_current_combatant() -> void:
	if not visible or current_combatant == null:
		return
	_rebuild_ability_buttons()


func _clear_ability_buttons() -> void:
	_ability_options.clear()
	for child in ability_list_container.get_children():
		child.queue_free()


func _rebuild_ability_buttons() -> void:
	_clear_ability_buttons()
	if current_combatant == null:
		return
	var first_enabled_index: int = -1
	var index: int = 0
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
		_ability_options.append(option)
		if can_use and first_enabled_index == -1:
			first_enabled_index = index
		index += 1
	if first_enabled_index >= 0:
		_highlight_option_by_index(first_enabled_index)
	elif ability_description_panel and ability_description_panel.has_method("clear_display"):
		ability_description_panel.call("clear_display")
		_highlighted_option_index = -1


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
	if not _ability_input_enabled:
		return
	if not _is_ability_currently_usable(ability):
		return
	if ability_description_panel and ability_description_panel.has_method("show_ability"):
		ability_description_panel.call("show_ability", ability)
	ability_selected.emit(ability)


func _on_option_hovered(ability: Ability) -> void:
	if ability == null:
		return
	for i in range(_ability_options.size()):
		var option: Button = _ability_options[i]
		if option and option.get("ability") == ability:
			_highlighted_option_index = i
			break
	if ability_description_panel and ability_description_panel.has_method("show_ability"):
		ability_description_panel.call("show_ability", ability)


func set_ability_input_enabled(enabled: bool) -> void:
	_ability_input_enabled = enabled
	for option in _ability_options:
		if option == null:
			continue
		option.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		if not enabled and option.has_focus():
			option.release_focus()
	if enabled:
		focus_current_or_first_ability()


func focus_current_or_first_ability() -> void:
	if _ability_options.is_empty():
		return
	if _highlighted_option_index >= 0 and _highlighted_option_index < _ability_options.size():
		var highlighted_option: Button = _ability_options[_highlighted_option_index]
		if highlighted_option and not highlighted_option.disabled:
			_highlight_option_by_index(_highlighted_option_index)
			return
	_highlight_first_usable_option()


func _highlight_first_usable_option() -> void:
	for i in range(_ability_options.size()):
		var option: Button = _ability_options[i]
		if option and not option.disabled:
			_highlight_option_by_index(i)
			return
	_highlighted_option_index = -1


func _highlight_option_by_index(index: int) -> void:
	if index < 0 or index >= _ability_options.size():
		return
	var option: Button = _ability_options[index]
	if option == null or option.disabled:
		return
	_highlighted_option_index = index
	option.grab_focus()
	var ability: Ability = option.get("ability") as Ability
	if ability and ability_description_panel and ability_description_panel.has_method("show_ability"):
		ability_description_panel.call("show_ability", ability)


func _move_highlight(direction: int) -> void:
	if _ability_options.is_empty():
		return
	var usable_indices: Array[int] = []
	for i in range(_ability_options.size()):
		var option: Button = _ability_options[i]
		if option and not option.disabled:
			usable_indices.append(i)
	if usable_indices.is_empty():
		return
	if _highlighted_option_index == -1:
		_highlight_option_by_index(usable_indices[0])
		return
	var current_list_index := usable_indices.find(_highlighted_option_index)
	if current_list_index == -1:
		_highlight_option_by_index(usable_indices[0])
		return
	var next_list_index := (current_list_index + direction) % usable_indices.size()
	if next_list_index < 0:
		next_list_index += usable_indices.size()
	_highlight_option_by_index(usable_indices[next_list_index])


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _ability_input_enabled:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move_highlight(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move_highlight(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_confirm_highlighted_option()
		get_viewport().set_input_as_handled()


func _confirm_highlighted_option() -> void:
	if _ability_options.is_empty():
		return
	if _highlighted_option_index < 0 or _highlighted_option_index >= _ability_options.size():
		_highlight_first_usable_option()
	if _highlighted_option_index < 0 or _highlighted_option_index >= _ability_options.size():
		return
	var option: Button = _ability_options[_highlighted_option_index]
	if option == null or option.disabled:
		return
	var ability: Ability = option.get("ability") as Ability
	if ability == null:
		return
	_on_option_selected(ability)
