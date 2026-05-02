extends Control
class_name EquipmentTooltip

## Populated by [method show_for_slot]. Author: wire each [Label] with [code]@onready ... = $MarginContainer/VBoxContainer/...[/code].
## Expected: [code]ItemNameLabel[/code] ([method Weapon.get_item_display_name]); [code]HBoxContainer[/code] with [code]TierLabel[/code] ([method Weapon.get_metal_tier_name] / [method Armour.get_tier_name]) and [code]TypeLabel[/code] (weapon type from [method Weapon.get_weapon_type_display_name], lowercased); then [code]HandStyleLabel[/code], [code]DamageBonusLabel[/code], [code]GrantedBasicsLabel[/code].
## [member mouse_filter] stays ignore so hover on equipment strips is not stolen.

@onready var label_item_name: Label = $MarginContainer/VBoxContainer/HBoxContainer2/ItemNameLabel
@onready var label_tier: Label = $MarginContainer/VBoxContainer/HBoxContainer2/TierLabel
@onready var label_item_type: Label = $MarginContainer/VBoxContainer/HBoxContainer/TypeLabel
@onready var label_hand_style: Label = $MarginContainer/VBoxContainer/HBoxContainer/HandStyleLabel
@onready var label_damage_bonus: Label = $MarginContainer/VBoxContainer/DamageBonusLabel
@onready var label_granted_basics: Label = $MarginContainer/VBoxContainer/GrantedBasicsLabel

@export var follow_mouse: bool = true
@export var offset_from_mouse: Vector2 = Vector2(16, 8)

## [code]weapon_type_id[/code] values that represent a dual-wield bundle when [member Weapon.occupies_both_slots] is true (see [code]COMBAT_DESIGN.md[/code] §16).
const DUAL_WIELD_BUNDLE_TYPE_IDS: Array[String] = ["daggers"]

var _tracking: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func _process(_delta: float) -> void:
	if not visible or not _tracking or not follow_mouse:
		return
	global_position = get_global_mouse_position() + offset_from_mouse
	_clamp_to_viewport()


func show_for_slot(member: HeroCharacter, which_slot: CharacterEquipmentStrip.Slot, _at_global: Vector2) -> void:
	if member == null:
		return
	member.ensure_default_weapon_slot_a()
	match which_slot:
		CharacterEquipmentStrip.Slot.MAIN_HAND:
			_apply_weapon_tooltip(member.get_weapon_slot_a(), member, "Main hand", true)
		CharacterEquipmentStrip.Slot.OFF_HAND:
			var w_a: Weapon = member.get_weapon_slot_a()
			if w_a != null and w_a.occupies_both_slots:
				_apply_off_hand_blocked_tooltip()
			elif member.get_weapon_slot_b() == null:
				_apply_empty_weapon_tooltip("Off hand", "No weapon equipped.")
			else:
				_apply_weapon_tooltip(member.get_weapon_slot_b(), member, "Off hand", false)
		CharacterEquipmentStrip.Slot.ARMOUR:
			var a: Armour = member.armour
			if a == null:
				a = Armour.create_default()
			_apply_armour_tooltip(a)
	_tracking = true
	visible = true
	global_position = get_global_mouse_position() + offset_from_mouse
	_clamp_to_viewport()


func hide_tooltip() -> void:
	_tracking = false
	visible = false


func _join_string_lines(lines: Array[String], sep: String) -> String:
	var out := ""
	for i in lines.size():
		if i > 0:
			out += sep
		out += lines[i]
	return out


func _clamp_to_viewport() -> void:
	var vr: Rect2 = get_viewport().get_visible_rect()
	var g: Vector2 = global_position
	g.x = clampf(g.x, vr.position.x, vr.position.x + vr.size.x - size.x)
	g.y = clampf(g.y, vr.position.y, vr.position.y + vr.size.y - size.y)
	global_position = g


func _apply_labels(
	item_name: String,
	tier_word: String,
	item_type: String,
	hand_style: String,
	damage_bonus: String,
	granted_basics: String,
) -> void:
	label_item_name.text = item_name
	label_tier.text = tier_word
	label_item_type.text = item_type
	label_hand_style.text = hand_style
	label_damage_bonus.text = damage_bonus
	label_granted_basics.text = granted_basics


func _apply_empty_weapon_tooltip(slot_title: String, subtitle: String) -> void:
	_apply_labels(slot_title, "—", "—", "—", "—", subtitle)


func _apply_off_hand_blocked_tooltip() -> void:
	_apply_labels(
		"Off hand",
		"—",
		"—",
		"Blocked",
		"—",
		"Occupied by the two-hand or dual-wield weapon in your main hand.",
	)


func _apply_weapon_tooltip(w: Weapon, _member: HeroCharacter, slot_title: String, _is_main: bool) -> void:
	if w == null:
		_apply_empty_weapon_tooltip(slot_title, "No weapon equipped.")
		return
	var item_name: String = w.get_item_display_name()
	var tier_word: String = w.get_metal_tier_name()
	var type_disp: String = w.get_weapon_type_display_name().to_lower()
	var hand: String = _weapon_hand_style_line(w)
	var dmg: String
	if w.contributes_attack_bonus:
		dmg = "+%d" % w.get_damage_bonus()
	else:
		dmg = "+%d (enchantments only)" % w.get_damage_bonus()
	var basics: String = _format_granted_basics(w)
	_apply_labels(item_name, tier_word, type_disp, hand, dmg, basics)


func _apply_armour_tooltip(a: Armour) -> void:
	var tier_word: String = a.get_tier_name()
	var item_name: String = "%s armour" % tier_word
	var type_line: String = "armour"
	var def_line: String = "+%d DEF" % a.get_def()
	_apply_labels(item_name, tier_word, type_line, "—", def_line, "—")


func _weapon_hand_style_line(w: Weapon) -> String:
	if not w.occupies_both_slots:
		return "One-hand"
	for dual_id in DUAL_WIELD_BUNDLE_TYPE_IDS:
		if w.weapon_type_id == dual_id:
			return "Dual-wield"
	return "Two-hand"


func _format_granted_basics(w: Weapon) -> String:
	if w.granted_basic_attacks.is_empty():
		return "—"
	var lines: Array[String] = []
	for ab in w.granted_basic_attacks:
		if ab == null:
			continue
		var n: String = ab.ability_name.strip_edges() if not ab.ability_name.is_empty() else ab.ability_id
		if n.is_empty():
			n = "Basic attack"
		lines.append(n)
	if lines.is_empty():
		return "—"
	return _join_string_lines(lines, "\n")
