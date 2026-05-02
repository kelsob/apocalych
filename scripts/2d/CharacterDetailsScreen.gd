extends Control

## CharacterDetailsScreen - Full character sheet opened when clicking a character in the party panel.
## Populates identity, stats, equipment strip icons, and inventory from a HeroCharacter.

signal closed()

const _DEFAULT_WEAPON_ICON_PATH: String = "res://assets/items/axe-1.png"
const _DEFAULT_ARMOUR_ICON_PATH: String = "res://assets/items/armor-1.png"

@onready var _name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/NameLabel
@onready var _level_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/Label
@onready var _race_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/RaceLabel
@onready var _class_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/ClassLabel
@onready var _current_hp_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/HBoxContainer3/HBoxContainer/CurrentHPLabel
@onready var _max_hp_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/HBoxContainer3/HBoxContainer/MaxHPLabel
@onready var _next_lvl_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/NextLvlLabel
@onready var _xp_to_lvl_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/XPToLvlLabel
@onready var _str_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer/HBoxContainer/Label2
@onready var _agi_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer/HBoxContainer2/Label2
@onready var _con_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer/HBoxContainer3/Label2
@onready var _spi_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer2/HBoxContainer/Label2
@onready var _cha_def_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer2/HBoxContainer2/Label2
@onready var _luk_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer2/HBoxContainer3/Label2

@onready var _equipment_strip_main_hand: CharacterEquipmentStrip = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/CharacterEquipmentStrip
@onready var _equipment_strip_off_hand: CharacterEquipmentStrip = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/CharacterEquipmentStrip2
@onready var _equipment_strip_armour: CharacterEquipmentStrip = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/CharacterEquipmentStrip3

@onready var _inventory_container: GridContainer = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/PanelContainer/MarginContainer/CharacterInventoryContainer
@onready var close_button: Button = $CloseButton

## Author: [code]@onready var equipment_tooltip: EquipmentTooltip = $YourPath[/code] when the tooltip node exists under this tree.
@onready var equipment_tooltip: EquipmentTooltip = $EquipmentTooltip

var _hp_progress_bar: ProgressBar = null  # Optional: add HPBar as child of HPXPContainer to show HP bar
var _open_member: HeroCharacter = null
var _hide_tooltip_timer: Timer = null


func _ready() -> void:
	_hp_progress_bar = get_node_or_null("PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/HPProgressBar") as ProgressBar
	visible = false
	if close_button:
		close_button.pressed.connect(close)
	var weapon_fallback: Texture2D = load(_DEFAULT_WEAPON_ICON_PATH) as Texture2D
	var armour_fallback: Texture2D = load(_DEFAULT_ARMOUR_ICON_PATH) as Texture2D
	for strip in [_equipment_strip_main_hand, _equipment_strip_off_hand]:
		if strip == null:
			continue
		strip.slot = CharacterEquipmentStrip.Slot.MAIN_HAND if strip == _equipment_strip_main_hand else CharacterEquipmentStrip.Slot.OFF_HAND
		if strip.default_weapon_texture == null and weapon_fallback:
			strip.default_weapon_texture = weapon_fallback
		if strip.empty_hand_texture == null and weapon_fallback:
			strip.empty_hand_texture = weapon_fallback
	if _equipment_strip_armour:
		_equipment_strip_armour.slot = CharacterEquipmentStrip.Slot.ARMOUR
		if _equipment_strip_armour.default_armour_texture == null and armour_fallback:
			_equipment_strip_armour.default_armour_texture = armour_fallback
	_connect_equipment_hover()
	_hide_tooltip_timer = Timer.new()
	_hide_tooltip_timer.one_shot = true
	_hide_tooltip_timer.wait_time = 0.12
	add_child(_hide_tooltip_timer)
	_hide_tooltip_timer.timeout.connect(_on_hide_equipment_tooltip_timer_timeout)


func _connect_equipment_hover() -> void:
	for strip in [_equipment_strip_main_hand, _equipment_strip_off_hand, _equipment_strip_armour]:
		if strip == null:
			continue
		strip.mouse_entered.connect(_on_equipment_strip_mouse_entered.bind(strip))
		strip.mouse_exited.connect(_on_equipment_strip_mouse_exited)


func _on_equipment_strip_mouse_entered(strip: CharacterEquipmentStrip) -> void:
	if _hide_tooltip_timer:
		_hide_tooltip_timer.stop()
	if _open_member == null:
		return
	equipment_tooltip.show_for_slot(_open_member, strip.slot, get_global_mouse_position())


func _on_equipment_strip_mouse_exited() -> void:
	if _hide_tooltip_timer:
		_hide_tooltip_timer.start()


func _on_hide_equipment_tooltip_timer_timeout() -> void:
	equipment_tooltip.hide_tooltip()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Populate the screen from a HeroCharacter. Call before showing.
func open_character(member: HeroCharacter) -> void:
	if not member:
		return
	equipment_tooltip.hide_tooltip()
	_open_member = member
	_populate_identity(member)
	_populate_hp_xp(member)
	_populate_stats(member)
	_populate_equipment(member)
	_populate_inventory(member)
	visible = true


func close() -> void:
	if _hide_tooltip_timer:
		_hide_tooltip_timer.stop()
	equipment_tooltip.hide_tooltip()
	_open_member = null
	visible = false
	closed.emit()


func _populate_identity(member: HeroCharacter) -> void:
	if _name_label:
		_name_label.text = member.member_name
	if _level_label:
		_level_label.text = "Lvl. %d" % member.level
	if _race_label:
		_race_label.text = member.race.race_name if member.race else "—"
	if _class_label:
		_class_label.text = member.class_resource.name if member.class_resource else "—"


func _populate_hp_xp(member: HeroCharacter) -> void:
	if _current_hp_label:
		_current_hp_label.text = str(member.current_health)
	if _max_hp_label:
		_max_hp_label.text = str(member.max_health)
	if _next_lvl_label:
		_next_lvl_label.text = "%d:" % (member.level + 1)
	if _xp_to_lvl_label:
		var xp_needed: int = member.experience_to_next_level - member.experience
		_xp_to_lvl_label.text = str(max(0, xp_needed))


func _populate_stats(member: HeroCharacter) -> void:
	var stats: Dictionary = member.get_final_stats()
	var d: int = HeroCharacter.PRIMARY_STAT_NEUTRAL
	if _str_label:
		_str_label.text = str(int(stats.get("strength", d)))
	if _agi_label:
		_agi_label.text = str(int(stats.get("agility", d)))
	if _con_label:
		_con_label.text = str(int(stats.get("constitution", d)))
	if _spi_label:
		_spi_label.text = str(int(stats.get("spirit", d)))
	if _cha_def_label:
		_cha_def_label.text = str(int(stats.get("intellect", d)))
	if _luk_label:
		_luk_label.text = str(int(stats.get("charisma", d)))


func _populate_equipment(member: HeroCharacter) -> void:
	if _equipment_strip_main_hand:
		_equipment_strip_main_hand.set_from_member(member)
	if _equipment_strip_off_hand:
		_equipment_strip_off_hand.set_from_member(member)
	if _equipment_strip_armour:
		_equipment_strip_armour.set_from_member(member)


func _populate_inventory(member: HeroCharacter) -> void:
	if _inventory_container:
		_inventory_container.populate_from_member(member)
