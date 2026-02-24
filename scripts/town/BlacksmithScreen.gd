extends Control

## BlacksmithScreen - View one character's weapon and armour at a time; upgrade them for gold or sharpening stones.
## Character buttons select which party member's equipment is shown; weapon and armour panels update accordingly.

signal blacksmith_closed()
signal party_gold_changed(new_gold: int)

const SHARPENING_STONE_ITEM_ID: String = "sharpening_stone"
const PREVIEW_GREEN: Color = Color(0.35, 0.95, 0.35)

# Costs to upgrade TO each tier: gold and sharpening stones (used for both weapon and armour)
const UPGRADE_COSTS: Dictionary = {
	Weapon.Tier.IRON: {"gold": 25, "stones": 1},
	Weapon.Tier.DIAMOND: {"gold": 75, "stones": 2},
	Weapon.Tier.PLATINUM: {"gold": 200, "stones": 3},
	Weapon.Tier.MITHRIL: {"gold": 500, "stones": 4},
}

# Optional: tier index -> icon path for weapon texture.
const WEAPON_TIER_ICON_PATHS: Array[String] = [
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
]

# Optional: tier index -> icon path for armour texture.
const ARMOUR_TIER_ICON_PATHS: Array[String] = [
	"res://assets/items/armor-1.png",
	"res://assets/items/armor-1.png",
	"res://assets/items/armor-1.png",
	"res://assets/items/armor-1.png",
	"res://assets/items/armor-1.png",
]

var _party_members: Array[PartyMember] = []
var _party_gold: int = 0
var _selected_character_index: int = -1

@onready var weapon_texture_rect: TextureRect = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterWeaponPanel/MarginContainer/VBoxContainer/WeaponTextureRect
@onready var weapon_name_label: Label = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterWeaponPanel/MarginContainer/VBoxContainer/WeaponNameLabel
@onready var weapon_atk_label: Label = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterWeaponPanel/MarginContainer/VBoxContainer/WeaponATKValueLabel
@onready var weapon_upgrade_tier_label: Label = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterWeaponPanel/MarginContainer/VBoxContainer/HBoxContainer2/UpgradeTierLabel
@onready var weapon_gold_upgrade_button: Button = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterWeaponPanel/MarginContainer/VBoxContainer/HBoxContainer/GoldUpgradeButton
@onready var weapon_stone_upgrade_button: Button = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterWeaponPanel/MarginContainer/VBoxContainer/HBoxContainer/SharpeningStoneUpgradeButton

@onready var armor_texture_rect: TextureRect = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterArmorPanel/MarginContainer/VBoxContainer/ArmorTextureRect
@onready var armor_name_label: Label = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterArmorPanel/MarginContainer/VBoxContainer/ArmorNameLabel
@onready var armor_def_label: Label = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterArmorPanel/MarginContainer/VBoxContainer/ArmorDEFValueLabel
@onready var armor_upgrade_tier_label: Label = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterArmorPanel/MarginContainer/VBoxContainer/HBoxContainer2/UpgradeTierLabel
@onready var armor_gold_upgrade_button: Button = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterArmorPanel/MarginContainer/VBoxContainer/HBoxContainer/GoldUpgradeButton
@onready var armor_stone_upgrade_button: Button = $MarginContainer/VBoxContainer/CharacterEquipmentPanel/CharacterArmorPanel/MarginContainer/VBoxContainer/HBoxContainer/SharpeningStoneUpgradeButton

@onready var character_button_1: Button = $PanelContainer/MarginContainer/VBoxContainer/CharacterButton1
@onready var character_button_2: Button = $PanelContainer/MarginContainer/VBoxContainer/CharacterButton2
@onready var character_button_3: Button = $PanelContainer/MarginContainer/VBoxContainer/CharacterButton3
@onready var _close_button: Button = $MarginContainer/VBoxContainer/Button

func _ready() -> void:
	visible = false
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	if character_button_1:
		character_button_1.pressed.connect(_on_character_button_pressed.bind(0))
	if character_button_2:
		character_button_2.pressed.connect(_on_character_button_pressed.bind(1))
	if character_button_3:
		character_button_3.pressed.connect(_on_character_button_pressed.bind(2))
	if weapon_gold_upgrade_button:
		weapon_gold_upgrade_button.pressed.connect(_on_weapon_gold_upgrade)
		weapon_gold_upgrade_button.mouse_entered.connect(_on_weapon_upgrade_hover_started)
		weapon_gold_upgrade_button.mouse_exited.connect(_on_weapon_upgrade_hover_ended)
	if weapon_stone_upgrade_button:
		weapon_stone_upgrade_button.pressed.connect(_on_weapon_stone_upgrade)
		weapon_stone_upgrade_button.mouse_entered.connect(_on_weapon_upgrade_hover_started)
		weapon_stone_upgrade_button.mouse_exited.connect(_on_weapon_upgrade_hover_ended)
	if armor_gold_upgrade_button:
		armor_gold_upgrade_button.pressed.connect(_on_armour_gold_upgrade)
		armor_gold_upgrade_button.mouse_entered.connect(_on_armour_upgrade_hover_started)
		armor_gold_upgrade_button.mouse_exited.connect(_on_armour_upgrade_hover_ended)
	if armor_stone_upgrade_button:
		armor_stone_upgrade_button.pressed.connect(_on_armour_stone_upgrade)
		armor_stone_upgrade_button.mouse_entered.connect(_on_armour_upgrade_hover_started)
		armor_stone_upgrade_button.mouse_exited.connect(_on_armour_upgrade_hover_ended)

func open_blacksmith(party_members: Array, party_gold: int) -> void:
	_party_members = party_members
	_party_gold = party_gold
	_selected_character_index = 0 if party_members.size() > 0 else -1
	_update_character_buttons()
	_refresh_equipment_panels()
	visible = true

func close_blacksmith() -> void:
	visible = false
	blacksmith_closed.emit()

func _update_character_buttons() -> void:
	var buttons: Array[Button] = [character_button_1, character_button_2, character_button_3]
	for i in range(3):
		var btn: Button = buttons[i] if i < buttons.size() else null
		if not btn:
			continue
		if i >= _party_members.size():
			btn.visible = false
			continue
		btn.visible = true
		var member: PartyMember = _party_members[i]
		btn.text = member.member_name if member else ("Character %d" % (i + 1))
		btn.button_pressed = (i == _selected_character_index)

func _on_character_button_pressed(index: int) -> void:
	if index < 0 or index >= _party_members.size():
		return
	_selected_character_index = index
	_update_character_buttons()
	_refresh_equipment_panels()

func _refresh_equipment_panels() -> void:
	weapon_atk_label.modulate = Color.WHITE
	armor_def_label.modulate = Color.WHITE
	var party_stones: int = _get_party_stone_count()
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		_clear_equipment_panels()
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
	var armour: Armour = member.armour if member.armour else Armour.create_default()

	# Weapon panel
	var w_tier: int = weapon.tier
	var w_target: int = w_tier + 1
	var w_max: bool = w_target > Weapon.Tier.MITHRIL
	weapon_name_label.text = "%s's %s %s" % [member.member_name, weapon.get_tier_name(), member.get_weapon_type()]
	weapon_atk_label.text = "+%d ATK" % weapon.get_atk()
	weapon_upgrade_tier_label.text = "Max tier" if w_max else Weapon.TIER_NAMES[w_target]
	var w_gold: int = 0
	var w_stones: int = 0
	if not w_max:
		var costs: Dictionary = UPGRADE_COSTS.get(w_target, {})
		w_gold = int(costs.get("gold", 0))
		w_stones = int(costs.get("stones", 0))
	weapon_gold_upgrade_button.text = str(w_gold)
	weapon_gold_upgrade_button.disabled = w_max or _party_gold < w_gold
	weapon_stone_upgrade_button.text = str(w_stones)
	weapon_stone_upgrade_button.disabled = w_max or party_stones < w_stones
	if WEAPON_TIER_ICON_PATHS.size() > w_tier and ResourceLoader.exists(WEAPON_TIER_ICON_PATHS[w_tier]):
		weapon_texture_rect.texture = load(WEAPON_TIER_ICON_PATHS[w_tier]) as Texture2D

	# Armour panel
	var a_tier: int = armour.tier
	var a_target: int = a_tier + 1
	var a_max: bool = a_target > Armour.Tier.MITHRIL
	armor_name_label.text = "%s's %s %s" % [member.member_name, armour.get_tier_name(), member.get_armour_type()]
	armor_def_label.text = "+%d DEF" % armour.get_def()
	armor_upgrade_tier_label.text = "Max tier" if a_max else Armour.TIER_NAMES[a_target]
	var a_gold: int = 0
	var a_stones: int = 0
	if not a_max:
		var costs: Dictionary = UPGRADE_COSTS.get(a_target, {})
		a_gold = int(costs.get("gold", 0))
		a_stones = int(costs.get("stones", 0))
	armor_gold_upgrade_button.text = str(a_gold)
	armor_gold_upgrade_button.disabled = a_max or _party_gold < a_gold
	armor_stone_upgrade_button.text = str(a_stones)
	armor_stone_upgrade_button.disabled = a_max or party_stones < a_stones
	if ARMOUR_TIER_ICON_PATHS.size() > a_tier and ResourceLoader.exists(ARMOUR_TIER_ICON_PATHS[a_tier]):
		armor_texture_rect.texture = load(ARMOUR_TIER_ICON_PATHS[a_tier]) as Texture2D

func _clear_equipment_panels() -> void:
	weapon_name_label.text = "—"
	weapon_atk_label.text = "—"
	weapon_upgrade_tier_label.text = "—"
	weapon_gold_upgrade_button.text = "0"
	weapon_gold_upgrade_button.disabled = true
	weapon_stone_upgrade_button.text = "0"
	weapon_stone_upgrade_button.disabled = true
	armor_name_label.text = "—"
	armor_def_label.text = "—"
	armor_upgrade_tier_label.text = "—"
	armor_gold_upgrade_button.text = "0"
	armor_gold_upgrade_button.disabled = true
	armor_stone_upgrade_button.text = "0"
	armor_stone_upgrade_button.disabled = true

func _get_party_stone_count() -> int:
	var total := 0
	for m in _party_members:
		if m is PartyMember:
			total += m.get_item_count(SHARPENING_STONE_ITEM_ID)
	return total

func _spend_party_stones(amount: int) -> void:
	var remaining: int = amount
	for m in _party_members:
		if remaining <= 0:
			break
		if m is PartyMember:
			var has: int = m.get_item_count(SHARPENING_STONE_ITEM_ID)
			var to_take: int = mini(has, remaining)
			if to_take > 0:
				m.remove_item(SHARPENING_STONE_ITEM_ID, to_take)
				remaining -= to_take

func _on_weapon_upgrade_hover_started() -> void:
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
	var w_target: int = weapon.tier + 1
	if w_target > Weapon.Tier.MITHRIL:
		return
	weapon_name_label.text = "%s's %s %s" % [member.member_name, Weapon.TIER_NAMES[w_target], member.get_weapon_type()]
	weapon_atk_label.text = "+%d ATK" % (w_target + 1)
	weapon_atk_label.modulate = PREVIEW_GREEN

func _on_weapon_upgrade_hover_ended() -> void:
	_refresh_equipment_panels()

func _on_armour_upgrade_hover_started() -> void:
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var armour: Armour = member.armour if member.armour else Armour.create_default()
	var a_target: int = armour.tier + 1
	if a_target > Armour.Tier.MITHRIL:
		return
	armor_name_label.text = "%s's %s %s" % [member.member_name, Armour.TIER_NAMES[a_target], member.get_armour_type()]
	armor_def_label.text = "+%d DEF" % a_target
	armor_def_label.modulate = PREVIEW_GREEN

func _on_armour_upgrade_hover_ended() -> void:
	_refresh_equipment_panels()

func _on_weapon_gold_upgrade() -> void:
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
	var target_tier: int = weapon.tier + 1
	if target_tier > Weapon.Tier.MITHRIL:
		return
	var costs: Dictionary = UPGRADE_COSTS.get(target_tier, {})
	var gold_cost: int = int(costs.get("gold", 0))
	if _party_gold < gold_cost:
		return
	_party_gold -= gold_cost
	party_gold_changed.emit(_party_gold)
	weapon.tier = target_tier
	_refresh_equipment_panels()

func _on_weapon_stone_upgrade() -> void:
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
	var target_tier: int = weapon.tier + 1
	if target_tier > Weapon.Tier.MITHRIL:
		return
	var costs: Dictionary = UPGRADE_COSTS.get(target_tier, {})
	var stone_cost: int = int(costs.get("stones", 0))
	if _get_party_stone_count() < stone_cost:
		return
	_spend_party_stones(stone_cost)
	weapon.tier = target_tier
	_refresh_equipment_panels()

func _on_armour_gold_upgrade() -> void:
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var armour: Armour = member.armour if member.armour else Armour.create_default()
	var target_tier: int = armour.tier + 1
	if target_tier > Armour.Tier.MITHRIL:
		return
	var costs: Dictionary = UPGRADE_COSTS.get(target_tier, {})
	var gold_cost: int = int(costs.get("gold", 0))
	if _party_gold < gold_cost:
		return
	_party_gold -= gold_cost
	party_gold_changed.emit(_party_gold)
	armour.tier = target_tier
	_refresh_equipment_panels()

func _on_armour_stone_upgrade() -> void:
	if _selected_character_index < 0 or _selected_character_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[_selected_character_index]
	var armour: Armour = member.armour if member.armour else Armour.create_default()
	var target_tier: int = armour.tier + 1
	if target_tier > Armour.Tier.MITHRIL:
		return
	var costs: Dictionary = UPGRADE_COSTS.get(target_tier, {})
	var stone_cost: int = int(costs.get("stones", 0))
	if _get_party_stone_count() < stone_cost:
		return
	_spend_party_stones(stone_cost)
	armour.tier = target_tier
	_refresh_equipment_panels()

func _on_close_pressed() -> void:
	close_blacksmith()
