extends Control

## BlacksmithScreen - View party weapons and upgrade them for gold or sharpening stones.

signal blacksmith_closed()
signal party_gold_changed(new_gold: int)

const SHARPENING_STONE_ITEM_ID: String = "sharpening_stone"

# Costs to upgrade TO each tier: gold and sharpening stones
const UPGRADE_COSTS: Dictionary = {
	Weapon.Tier.IRON: {"gold": 25, "stones": 1},
	Weapon.Tier.DIAMOND: {"gold": 75, "stones": 2},
	Weapon.Tier.PLATINUM: {"gold": 200, "stones": 3},
	Weapon.Tier.MITHRIL: {"gold": 500, "stones": 4},
}

# Optional: tier index -> icon path for weapon texture. Leave empty to use scene default.
const TIER_ICON_PATHS: Array[String] = [
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
	"res://assets/items/axe-1.png",
]

var _party_members: Array[PartyMember] = []
var _party_gold: int = 0

@onready var _panel_1: Control = $MarginContainer/VBoxContainer/HBoxContainer/CharacterWeaponPanel
@onready var _panel_2: Control = $MarginContainer/VBoxContainer/HBoxContainer/CharacterWeaponPanel2
@onready var _panel_3: Control = $MarginContainer/VBoxContainer/HBoxContainer/CharacterWeaponPanel3
@onready var _close_button: Button = $MarginContainer/VBoxContainer/Button

func _ready() -> void:
	visible = false
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	_connect_panel_signals()

func _connect_panel_signals() -> void:
	for i in range(3):
		var panel = _get_panel(i)
		if panel and panel.has_signal("upgrade_gold_requested"):
			panel.upgrade_gold_requested.connect(_on_upgrade_gold_requested.bind(i))
		if panel and panel.has_signal("upgrade_stone_requested"):
			panel.upgrade_stone_requested.connect(_on_upgrade_stone_requested.bind(i))

func _get_panel(index: int) -> Control:
	match index:
		0: return _panel_1
		1: return _panel_2
		2: return _panel_3
	return null

func open_blacksmith(party_members: Array, party_gold: int) -> void:
	_party_members = party_members
	_party_gold = party_gold
	_populate_panels()
	visible = true

func close_blacksmith() -> void:
	visible = false
	blacksmith_closed.emit()

func _populate_panels() -> void:
	var party_stones: int = _get_party_stone_count()
	for i in range(3):
		var panel = _get_panel(i)
		if not panel or not panel.has_method("setup"):
			continue
		if i >= _party_members.size():
			panel.visible = false
			continue
		panel.visible = true
		var member: PartyMember = _party_members[i]
		var weapon: Weapon = member.weapon if member.weapon else Weapon.create_default()
		var current_tier: int = weapon.tier
		var target_tier: int = current_tier + 1
		var is_max_tier: bool = target_tier > Weapon.Tier.MITHRIL

		var weapon_name: String = "%s's %s" % [member.member_name, weapon.get_tier_name()]
		var target_tier_name: String = "Max tier" if is_max_tier else Weapon.TIER_NAMES[target_tier]
		var gold_cost: int = 0
		var stone_cost: int = 0
		var can_afford_gold: bool = false
		var can_afford_stones: bool = false

		if not is_max_tier:
			var costs: Dictionary = UPGRADE_COSTS.get(target_tier, {})
			gold_cost = int(costs.get("gold", 0))
			stone_cost = int(costs.get("stones", 0))
			can_afford_gold = _party_gold >= gold_cost
			can_afford_stones = party_stones >= stone_cost

		var texture: Texture2D = null
		if TIER_ICON_PATHS.size() > current_tier:
			var path: String = TIER_ICON_PATHS[current_tier]
			if ResourceLoader.exists(path):
				texture = load(path) as Texture2D

		panel.setup(weapon_name, target_tier_name, gold_cost, stone_cost, texture, is_max_tier, can_afford_gold, can_afford_stones)

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

func _on_upgrade_gold_requested(member_index: int) -> void:
	if member_index < 0 or member_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[member_index]
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
	_populate_panels()

func _on_upgrade_stone_requested(member_index: int) -> void:
	if member_index < 0 or member_index >= _party_members.size():
		return
	var member: PartyMember = _party_members[member_index]
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
	_populate_panels()

func _on_close_pressed() -> void:
	close_blacksmith()
