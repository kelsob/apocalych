extends Resource
class_name Item

## Item resource - defines an item loaded from JSON
## Use ItemDatabase.get_item(id) to retrieve items by id

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum ItemType { MISC, CONSUMABLE, EQUIPMENT, QUEST, CURRENCY }

const RARITY_STRINGS := ["common", "uncommon", "rare", "legendary"]
const ITEM_TYPE_STRINGS := ["misc", "consumable", "equipment", "quest", "currency"]

@export var id: String = ""
@export var name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var value: int = 0
@export var description: String = ""
@export var class_restriction: Array[String] = []
@export var item_type: ItemType = ItemType.MISC
@export var stack_size: int = 99
@export var icon_path: String = ""
@export var extra: Dictionary = {}

## Create an Item Resource from a JSON-parsed Dictionary
static func create_from_dict(data: Dictionary) -> Item:
	var item := Item.new()
	item.id = str(data.get("id", ""))
	item.name = str(data.get("name", ""))
	item.rarity = _parse_rarity(data.get("rarity", "common"))
	item.value = int(data.get("value", 0))
	item.description = str(data.get("description", ""))
	item.class_restriction = _parse_class_restriction(data.get("class_restriction"))
	item.item_type = _parse_item_type(data.get("item_type", "misc"))
	item.stack_size = int(data.get("stack_size", 99))
	item.stack_size = maxi(1, item.stack_size)
	item.icon_path = str(data.get("icon", ""))
	if data.has("extra") and data.extra is Dictionary:
		item.extra = data.extra
	return item

static func _parse_rarity(val: Variant) -> Rarity:
	match str(val).to_lower():
		"uncommon": return Rarity.UNCOMMON
		"rare": return Rarity.RARE
		"legendary": return Rarity.LEGENDARY
		_: return Rarity.COMMON

static func _parse_item_type(val: Variant) -> ItemType:
	match str(val).to_lower():
		"consumable": return ItemType.CONSUMABLE
		"equipment": return ItemType.EQUIPMENT
		"quest": return ItemType.QUEST
		"currency": return ItemType.CURRENCY
		_: return ItemType.MISC

static func _parse_class_restriction(val: Variant) -> Array[String]:
	var arr: Array[String] = []
	if val == null:
		return arr
	if val is Array:
		for v in val:
			arr.append(str(v))
	return arr

## Check if this item can be used by a class id
func is_usable_by(class_id: String) -> bool:
	if class_restriction.is_empty():
		return true
	return class_id in class_restriction

## Get rarity as display string
func get_rarity_string() -> String:
	return RARITY_STRINGS[rarity]

## Get item type as string
func get_item_type_string() -> String:
	return ITEM_TYPE_STRINGS[item_type]
