extends RefCounted
class_name CombatTestSupport

## Static helpers for the combat test lab: discover resources, build heroes, tune gear/level.

const ENCOUNTERS_DIR: String = "res://resources/encounters"
const HEROES_DIR: String = "res://resources/heroes"


static func collect_tres_paths(root_dir: String, recursive: bool = true) -> Array[String]:
	var out: Array[String] = []
	if recursive:
		_collect_tres_recursive(root_dir, out)
	else:
		var dir := DirAccess.open(root_dir)
		if not dir:
			push_warning("CombatTestSupport: cannot open %s" % root_dir)
			return out
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if not dir.current_is_dir() and fn.ends_with(".tres"):
				out.append(root_dir.rstrip("/") + "/" + fn)
			fn = dir.get_next()
		dir.list_dir_end()
	return out


static func _collect_tres_recursive(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn != "." and fn != "..":
			var full: String = dir_path.rstrip("/") + "/" + fn
			if dir.current_is_dir():
				_collect_tres_recursive(full, out)
			elif fn.ends_with(".tres"):
				out.append(full)
		fn = dir.get_next()
	dir.list_dir_end()


static func list_combat_encounters() -> Array[Dictionary]:
	var paths := collect_tres_paths(ENCOUNTERS_DIR, true)
	paths.sort()
	var rows: Array[Dictionary] = []
	for p in paths:
		var enc := load(p)
		if enc is CombatEncounter:
			var ce := enc as CombatEncounter
			rows.append({
				"path": p,
				"id": ce.encounter_id,
				"name": ce.encounter_name if not ce.encounter_name.is_empty() else ce.encounter_id,
				"resource": ce
			})
	return rows


static func list_hero_templates() -> Array[Dictionary]:
	var paths := collect_tres_paths(HEROES_DIR, true)
	paths.sort()
	var rows: Array[Dictionary] = []
	for p in paths:
		var hr = load(p)
		if hr is HeroCharacter:
			var h := hr as HeroCharacter
			rows.append({
				"path": p,
				"id": h.hero_id,
				"name": h.member_name if not h.member_name.is_empty() else h.hero_id,
				"resource": h
			})
	return rows


static func load_encounter(path: String) -> CombatEncounter:
	var r = load(path)
	return r as CombatEncounter


## Duplicate a hero template, call [method HeroCharacter.initialize], then apply progression/gear.
static func create_hero_from_template(hero_path: String) -> HeroCharacter:
	var r = load(hero_path)
	if r is HeroCharacter:
		var inst: HeroCharacter = (r as HeroCharacter).duplicate(true)
		inst.initialize()
		return inst
	push_warning("CombatTestSupport: not a HeroCharacter: %s" % hero_path)
	return null


static func set_hero_level(hero: HeroCharacter, target_level: int) -> void:
	target_level = maxi(1, target_level)
	var guard := 0
	while hero.level < target_level and guard < 300:
		var need: int = hero.experience_to_next_level - hero.experience
		hero.gain_experience(max(1, need))
		guard += 1


static func set_weapon_tier(hero: HeroCharacter, tier: int) -> void:
	if hero.weapon == null:
		hero.weapon = Weapon.create_default()
	tier = clampi(tier, 0, Weapon.Tier.MITHRIL)
	hero.weapon.tier = tier


static func set_armour_tier(hero: HeroCharacter, tier: int) -> void:
	if hero.armour == null:
		hero.armour = Armour.create_default()
	tier = clampi(tier, 0, Armour.Tier.MITHRIL)
	hero.armour.tier = tier


static func build_party_from_template(
	hero_path: String,
	party_size: int,
	target_level: int,
	weapon_tier: int,
	armour_tier: int
) -> Array[HeroCharacter]:
	var out: Array[HeroCharacter] = []
	party_size = clampi(party_size, 1, 4)
	for i in party_size:
		var h := create_hero_from_template(hero_path)
		if h == null:
			continue
		h.member_name = "%s %d" % [h.member_name, i + 1] if party_size > 1 else h.member_name
		set_hero_level(h, target_level)
		set_weapon_tier(h, weapon_tier)
		set_armour_tier(h, armour_tier)
		out.append(h)
	return out


static func full_heal_party(party: Array[HeroCharacter]) -> void:
	for m in party:
		if m:
			m.current_health = m.max_health


static func party_status_summary(party: Array[HeroCharacter]) -> String:
	var lines: PackedStringArray = []
	for m in party:
		if m is HeroCharacter:
			var h := m as HeroCharacter
			lines.append(
				"%s — Lv %d — HP %d/%d — XP %d"
				% [h.member_name, h.level, h.current_health, h.max_health, h.experience]
			)
	return "\n".join(lines)


static func rewards_summary(rewards: Dictionary) -> String:
	var fled: bool = rewards.get("fled", false)
	var xp: int = int(rewards.get("xp", 0))
	var gold: int = int(rewards.get("gold", 0))
	var vic: bool = rewards.get("victory", false)
	if fled:
		return "Fled — XP (from kills): %d — Gold: %d" % [xp, gold]
	if vic:
		return "Victory — XP: %d — Gold: %d" % [xp, gold]
	return "Defeat — XP: %d — Gold: %d" % [xp, gold]


## Every item id from ItemDatabase for test-lab pickers, except currency and optional resource-tagged rows.
## Skips [constant Item.ItemType.CURRENCY]. Skips [code]extra.is_resource == true[/code] when set in JSON (crafting mats etc.).
static func list_carriable_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id in ItemDatabase.get_all_ids():
		var it: Item = ItemDatabase.get_item(item_id)
		if it == null:
			continue
		if it.item_type == Item.ItemType.CURRENCY:
			continue
		if it.extra.get("is_resource", false) == true:
			continue
		ids.append(item_id)
	ids.sort()
	return ids


## Stub entries until combat modifiers exist in data. [code]{ "id": String, "label": String }[/code]
static func list_combat_modifier_placeholders() -> Array[Dictionary]:
	return [
		{"id": "", "label": "— (combat modifiers not implemented) —"}
	]


static func apply_items_to_hero(hero: HeroCharacter, item_ids: Array[String]) -> void:
	for item_id in item_ids:
		if item_id.is_empty():
			continue
		hero.add_item(item_id, 1)


## Build up to three heroes from per-slot template paths; skips empty slots.
static func build_party_from_slots(
	hero_paths: Array[String],
	slot_levels: Array[int],
	inventory_item_ids_per_slot: Array[Array]
) -> Array[HeroCharacter]:
	var out: Array[HeroCharacter] = []
	for i in hero_paths.size():
		var p: String = hero_paths[i]
		if p.is_empty():
			continue
		var h: HeroCharacter = create_hero_from_template(p)
		if h == null:
			continue
		var lv: int = slot_levels[i] if i < slot_levels.size() else 1
		set_hero_level(h, lv)
		if i < inventory_item_ids_per_slot.size():
			apply_items_to_hero(h, inventory_item_ids_per_slot[i])
		out.append(h)
	return out
