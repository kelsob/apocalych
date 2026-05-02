extends Control
class_name CharacterEquipmentStrip

## One equipment icon slot: **main hand**, **off hand**, or **armour**. Use three instances in a row.
## Prefer [member Weapon.ui_icon] / [member Armour.ui_icon]; otherwise [member fallback_by_weapon_type_id] by [member Weapon.weapon_type_id].

enum Slot {
	MAIN_HAND,
	OFF_HAND,
	ARMOUR,
}

@export var slot: Slot = Slot.MAIN_HAND
@export var texture_rect: TextureRect

@export var empty_hand_texture: Texture2D
@export var default_weapon_texture: Texture2D
@export var default_armour_texture: Texture2D

## Optional: keys = [member Weapon.weapon_type_id]. Values = [Texture2D] or [code]res://...[/code] path string.
@export var fallback_by_weapon_type_id: Dictionary = {}


func _ready() -> void:
	if texture_rect == null:
		texture_rect = get_node_or_null("MarginContainer/TextureRect") as TextureRect


## Updates this instance’s [member texture_rect] from the hero’s loadout.
func set_from_member(member: HeroCharacter) -> void:
	if member == null:
		return
	var rect := _resolve_rect()
	if rect == null:
		return
	member.ensure_default_weapon_slot_a()
	var w_a: Weapon = member.get_weapon_slot_a()
	var w_b: Weapon = member.get_weapon_slot_b()
	var arm: Armour = member.armour
	if arm == null:
		arm = Armour.create_default()
	var a_uses_both: bool = w_a != null and w_a.occupies_both_slots
	match slot:
		Slot.MAIN_HAND:
			_apply_texture(rect, _resolve_weapon_texture(w_a))
		Slot.OFF_HAND:
			if a_uses_both or w_b == null:
				_apply_texture(rect, empty_hand_texture)
			else:
				_apply_texture(rect, _resolve_weapon_texture(w_b))
		Slot.ARMOUR:
			_apply_texture(rect, _resolve_armour_texture(arm))


func _resolve_rect() -> TextureRect:
	if texture_rect:
		return texture_rect
	return get_node_or_null("MarginContainer/TextureRect") as TextureRect


func _resolve_weapon_texture(w: Weapon) -> Texture2D:
	if w == null:
		return empty_hand_texture if empty_hand_texture else default_weapon_texture
	if w.ui_icon:
		return w.ui_icon
	var tid: String = w.weapon_type_id
	if fallback_by_weapon_type_id.has(tid):
		var t: Variant = fallback_by_weapon_type_id[tid]
		if t is Texture2D:
			return t
		if t is String and ResourceLoader.exists(str(t)):
			return load(str(t)) as Texture2D
	return default_weapon_texture


func _resolve_armour_texture(a: Armour) -> Texture2D:
	if a == null:
		return default_armour_texture
	if a.ui_icon:
		return a.ui_icon
	return default_armour_texture


func _apply_texture(rect: TextureRect, tex: Texture2D) -> void:
	if rect == null:
		return
	rect.texture = tex
