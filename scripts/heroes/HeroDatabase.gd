extends RefCounted
class_name HeroDatabase

## Design-time registry for hero **templates** (`HeroCharacter` .tres under `res://resources/heroes/`).
## Runtime party uses **duplicates** from `instantiate_for_run()`. Paths are hard-coded by design.

const STARTER_HUMAN_CHAMPION := "res://resources/heroes/starter_human_champion.tres"
const STARTER_ELF_WIZARD := "res://resources/heroes/starter_elf_wizard.tres"
const STARTER_DWARF_CLERIC := "res://resources/heroes/starter_dwarf_cleric.tres"
const STARTER_HOBBIT_ROGUE := "res://resources/heroes/starter_hobbit_rogue.tres"

## Optional fifth+ templates: hidden from party select until `MetaProgression` unlocks them (cross-run).
const UNLOCKABLE_SELLSWORD := "res://resources/heroes/unlockable_sellsword.tres"


## The four default starters (always offered on party select).
static func default_starter_template_paths() -> Array[String]:
	return [
		STARTER_HUMAN_CHAMPION,
		STARTER_ELF_WIZARD,
		STARTER_DWARF_CLERIC,
		STARTER_HOBBIT_ROGUE,
	]


## Templates that can be **meta-unlocked** (not shown until unlocked). Add new paths here when you add heroes.
static func meta_unlockable_template_paths() -> Array[String]:
	return [
		UNLOCKABLE_SELLSWORD,
	]


static func is_meta_unlockable_hero_id(hero_id: String) -> bool:
	var hid := hero_id.strip_edges()
	if hid.is_empty():
		return false
	for p in meta_unlockable_template_paths():
		var t: HeroCharacter = load_template(p)
		if t and t.hero_id == hid:
			return true
	return false


## Party select: default starters **plus** any meta-unlocked optional heroes.
static func party_select_template_paths() -> Array[String]:
	MetaProgression.ensure_loaded()
	var out: Array[String] = []
	out.append_array(default_starter_template_paths())
	for p in meta_unlockable_template_paths():
		var t: HeroCharacter = load_template(p)
		if t == null:
			continue
		if MetaProgression.is_hero_unlocked(t.hero_id):
			out.append(p)
	return out


## All templates used for `hero_id` lookup (starters + meta-unlock pool).
static func all_known_template_paths() -> Array[String]:
	var out: Array[String] = []
	out.append_array(default_starter_template_paths())
	out.append_array(meta_unlockable_template_paths())
	return out


## Back-compat name: the **four** default starters only (not meta unlockables).
static func starter_template_paths() -> Array[String]:
	return default_starter_template_paths()


static func load_template(path: String) -> HeroCharacter:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("HeroDatabase.load_template: missing resource '%s'" % path)
		return null
	var r: Resource = ResourceLoader.load(path)
	if r is HeroCharacter:
		return r as HeroCharacter
	push_warning("HeroDatabase.load_template: not a HeroCharacter: '%s'" % path)
	return null


## Fresh hero for a run: deep duplicate + `initialize()` (HP, gear, portrait roll).
static func instantiate_for_run(template_path: String) -> HeroCharacter:
	var t := load_template(template_path)
	if t == null:
		return null
	var h: HeroCharacter = t.duplicate(true)
	h.initialize()
	return h


## Resolve `res://...` template path for a known `hero_id` (starters + meta-unlock templates).
static func template_path_for_hero_id(hero_id: String) -> String:
	if hero_id.is_empty():
		return ""
	for p in all_known_template_paths():
		var t: HeroCharacter = load_template(p)
		if t and t.hero_id == hero_id:
			return p
	return ""


static func display_label_for_template(path: String) -> String:
	var t := load_template(path)
	if t == null:
		return path.get_file().get_basename()
	if not t.member_name.is_empty():
		return t.member_name
	if not t.hero_id.is_empty():
		return t.hero_id
	return path.get_file().get_basename()


## Fill an OptionButton: item text = display name, metadata = template path (String).
static func populate_starter_option_button(ob: OptionButton) -> void:
	if ob == null:
		return
	ob.clear()
	for path in party_select_template_paths():
		ob.add_item(display_label_for_template(path))
		ob.set_item_metadata(ob.item_count - 1, path)
