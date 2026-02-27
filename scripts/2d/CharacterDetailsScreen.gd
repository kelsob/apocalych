extends Control

## CharacterDetailsScreen - Full character sheet opened when clicking a character in the party panel.
## Populates identity, stats, equipment, and inventory from a PartyMember.

signal closed()

const WEAPON_ICON_PATH: String = "res://assets/items/axe-1.png"
const ARMOUR_ICON_PATH: String = "res://assets/items/armor-1.png"

@onready var _name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/NameLabel
@onready var _level_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/Label
@onready var _race_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/RaceLabel
@onready var _class_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/IdentityContainer/ClassLabel
@onready var _current_hp_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/HBoxContainer3/HBoxContainer/CurrentHPLabel
@onready var _max_hp_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/HBoxContainer3/HBoxContainer/MaxHPLabel
@onready var _next_lvl_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/NextLvlLabel
@onready var _xp_to_lvl_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/XPToLvlLabel
@onready var _atk_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer/HBoxContainer/Label2
@onready var _mag_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer/HBoxContainer2/Label2
@onready var _spd_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer/HBoxContainer3/Label2
@onready var _def_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer2/HBoxContainer/Label2
@onready var _mag_def_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer2/HBoxContainer2/Label2
@onready var _luk_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/VBoxContainer2/HBoxContainer3/Label2
@onready var _weapon_texture: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/HBoxContainer/PanelContainer/MarginContainer/WeaponTextureRect
@onready var _weapon_name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/WeaponName
@onready var _weapon_atk_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/ATKLabel
@onready var _armour_texture: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/HBoxContainer2/PanelContainer/MarginContainer/ArmorTextureRect
@onready var _armour_name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/HBoxContainer2/PanelContainer2/MarginContainer/VBoxContainer/ArmorName
@onready var _armour_def_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer/HBoxContainer2/PanelContainer2/MarginContainer/VBoxContainer/DEFLabel
@onready var _inventory_container: GridContainer = $PanelContainer/MarginContainer/HBoxContainer/LeftPanel/PanelContainer/MarginContainer/CharacterInventoryContainer
@onready var close_button: Button = $CloseButton

var _hp_progress_bar: ProgressBar = null  # Optional: add HPProgressBar as child of HPXPContainer to show HP bar

func _ready() -> void:
	_hp_progress_bar = get_node_or_null("PanelContainer/MarginContainer/HBoxContainer/LeftPanel/HPXPContainer/HPProgressBar") as ProgressBar
	visible = false
	if close_button:
		close_button.pressed.connect(close)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## Populate the screen from a PartyMember. Call before showing.
func open_character(member: PartyMember) -> void:
	if not member:
		return
	_populate_identity(member)
	_populate_hp_xp(member)
	_populate_stats(member)
	_populate_equipment(member)
	_populate_inventory(member)
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _populate_identity(member: PartyMember) -> void:
	if _name_label:
		_name_label.text = member.member_name
	if _level_label:
		_level_label.text = "Lvl. %d" % member.level
	if _race_label:
		_race_label.text = member.race.race_name if member.race else "—"
	if _class_label:
		_class_label.text = member.class_resource.name if member.class_resource else "—"

func _populate_hp_xp(member: PartyMember) -> void:
	if _current_hp_label:
		_current_hp_label.text = str(member.current_health)
	if _max_hp_label:
		_max_hp_label.text = str(member.max_health)
	if _hp_progress_bar:
		_hp_progress_bar.min_value = 0
		_hp_progress_bar.max_value = member.max_health if member.max_health > 0 else 1
		_hp_progress_bar.value = member.current_health
	if _next_lvl_label:
		_next_lvl_label.text = "%d:" % (member.level + 1)
	if _xp_to_lvl_label:
		var xp_needed: int = member.experience_to_next_level - member.experience
		_xp_to_lvl_label.text = str(max(0, xp_needed))

func _populate_stats(member: PartyMember) -> void:
	var stats: Dictionary = member.get_final_stats()
	var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
	var armour: Armour = member.armour if member.armour else Armour.create_default()
	# ATK = strength + weapon bonus, MAG = int, SPD = dex, DEF = armour, MAG-DEF = wis, LUK = cha
	var atk: int = stats.get("strength", 10) + weapon.get_damage_bonus()
	if _atk_label:
		_atk_label.text = str(atk)
	if _mag_label:
		_mag_label.text = str(stats.get("intelligence", 10))
	if _spd_label:
		_spd_label.text = str(stats.get("dexterity", 10))
	if _def_label:
		_def_label.text = str(armour.get_def())
	if _mag_def_label:
		_mag_def_label.text = str(stats.get("wisdom", 10))
	if _luk_label:
		_luk_label.text = str(stats.get("charisma", 10))

func _populate_equipment(member: PartyMember) -> void:
	var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
	var armour: Armour = member.armour if member.armour else Armour.create_default()
	if _weapon_texture:
		var tex: Texture2D = load(WEAPON_ICON_PATH) as Texture2D
		_weapon_texture.texture = tex
	if _weapon_name_label:
		_weapon_name_label.text = "%s %s" % [weapon.get_tier_name(), member.get_weapon_type()]
	if _weapon_atk_label:
		_weapon_atk_label.text = "+%d ATK" % weapon.get_damage_bonus()
	if _armour_texture:
		var tex: Texture2D = load(ARMOUR_ICON_PATH) as Texture2D
		_armour_texture.texture = tex
	if _armour_name_label:
		_armour_name_label.text = "%s %s" % [armour.get_tier_name(), member.get_armour_type()]
	if _armour_def_label:
		_armour_def_label.text = "+%d DEF" % armour.get_def()

func _populate_inventory(member: PartyMember) -> void:
	if _inventory_container:
		_inventory_container.populate_from_member(member)
