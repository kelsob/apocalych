extends Node

## ItemDatabase - loads item definitions from JSON and provides lookup
## Add as autoload (Project Settings -> Autoload) with name "ItemDatabase"
## Loads from res://data/items/ by default; supports multiple JSON files

# Registry: item_id -> Item Resource
var _items: Dictionary = {}

# Default directory for item JSON files
@export var items_directory: String = "res://data/items"

func _ready() -> void:
	load_items_from_directory(items_directory)

## Load items from a single JSON file (root must be array of item objects)
func load_items_from_json(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ItemDatabase: Could not open file: %s" % path)
		return 0

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("ItemDatabase: Failed to parse JSON %s: %s" % [path, json.get_error_message()])
		return 0

	var data = json.data
	if not data is Array:
		push_error("ItemDatabase: JSON root must be an array of items: %s" % path)
		return 0

	var loaded := 0
	for entry in data:
		if not entry is Dictionary:
			push_warning("ItemDatabase: Skipping non-object entry in %s" % path)
			continue
		if not entry.has("id"):
			push_warning("ItemDatabase: Skipping item missing 'id' in %s" % path)
			continue

		var item := Item.create_from_dict(entry)
		if _items.has(item.id):
			push_warning("ItemDatabase: Duplicate item id '%s', overwriting" % item.id)
		_items[item.id] = item
		loaded += 1

	print("ItemDatabase: Loaded %d items from %s (total: %d)" % [loaded, path, _items.size()])
	return loaded

## Load all .json files from a directory (excluding .schema.json)
func load_items_from_directory(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("ItemDatabase: Could not open directory: %s" % dir_path)
		return 0

	var total := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and not file_name.ends_with(".schema.json"):
			total += load_items_from_json(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return total

## Get an Item by id, or null if not found
func get_item(item_id: String) -> Item:
	return _items.get(item_id)

## Check if an item exists
func has_item(item_id: String) -> bool:
	return _items.has(item_id)

## Get all loaded item IDs
func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _items.keys():
		ids.append(k)
	return ids

## Get all loaded Items
func get_all_items() -> Array[Item]:
	var result: Array[Item] = []
	for item in _items.values():
		result.append(item)
	return result
