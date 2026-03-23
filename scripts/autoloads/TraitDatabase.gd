extends Node

## TraitDatabase — loads trait definitions from JSON and provides lookup.
## Register as autoload with name "TraitDatabase" in Project Settings → Autoload.
## Place trait JSON files in res://data/traits/ (array of trait objects per file).

var _traits: Dictionary = {}

func _ready() -> void:
	_load_from_directory("res://data/traits")

func _load_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("TraitDatabase: Could not open directory: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_from_file(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("TraitDatabase: Loaded %d traits total" % _traits.size())

func _load_from_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("TraitDatabase: Could not open file: %s" % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("TraitDatabase: Failed to parse %s: %s" % [path, json.get_error_message()])
		return
	var data = json.data
	if not data is Array:
		push_error("TraitDatabase: JSON root must be an array in %s" % path)
		return
	var loaded := 0
	for entry in data:
		if not entry is Dictionary or not entry.has("id"):
			push_warning("TraitDatabase: Skipping entry missing 'id' in %s" % path)
			continue
		var t := Trait.create_from_dict(entry)
		if _traits.has(t.id):
			push_warning("TraitDatabase: Duplicate trait id '%s', overwriting" % t.id)
		_traits[t.id] = t
		loaded += 1
	print("TraitDatabase: Loaded %d traits from %s" % [loaded, path])

func get_trait(trait_id: String) -> Trait:
	return _traits.get(trait_id)

func has_trait(trait_id: String) -> bool:
	return _traits.has(trait_id)

func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _traits.keys():
		ids.append(k)
	return ids
