extends RefCounted
class_name MetaProgression

## Cross-run persistence (outside individual saves). Stored under `user://` — survives quit/relaunch.
## Currently: which **meta-unlock** hero templates appear on the party select screen after being unlocked in play.

const SAVE_PATH := "user://meta_progression.json"
const SAVE_VERSION := 1

static var _unlocked_hero_ids: Array[String] = []
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_unlocked_hero_ids.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("MetaProgression: could not read %s" % SAVE_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var p := JSON.new()
	if p.parse(txt) != OK:
		push_warning("MetaProgression: invalid JSON in %s" % SAVE_PATH)
		return
	var root: Variant = p.data
	if root is Dictionary:
		var d: Dictionary = root
		var arr: Variant = d.get("unlocked_heroes", [])
		if arr is Array:
			for x in arr:
				var s := str(x).strip_edges()
				if not s.is_empty():
					if not _unlocked_hero_ids.has(s):
						_unlocked_hero_ids.append(s)


static func _save() -> void:
	var d := {
		"version": SAVE_VERSION,
		"unlocked_heroes": _unlocked_hero_ids.duplicate(),
	}
	var json := JSON.stringify(d, "\t")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("MetaProgression: could not write %s" % SAVE_PATH)
		return
	f.store_string(json)
	f.close()


static func is_hero_unlocked(hero_id: String) -> bool:
	var hid := hero_id.strip_edges()
	if hid.is_empty():
		return false
	return _unlocked_hero_ids.has(hid)


## Persists unlock for future party-select runs. Callers should validate `hero_id` against `HeroDatabase.is_meta_unlockable_hero_id` when using meta-unlock templates.
static func unlock_hero(hero_id: String) -> void:
	ensure_loaded()
	var hid := hero_id.strip_edges()
	if hid.is_empty():
		push_warning("MetaProgression: unlock_hero got empty hero_id")
		return
	if _unlocked_hero_ids.has(hid):
		return
	_unlocked_hero_ids.append(hid)
	_save()
	print("MetaProgression: unlocked hero '%s' for future runs" % hid)


## Clears all meta progression and rewrites the save file. Wire an Options menu button to this for testing.
static func reset_all_meta() -> void:
	ensure_loaded()
	_unlocked_hero_ids.clear()
	_save()
	print("MetaProgression: reset all meta progression (%s)" % SAVE_PATH)
