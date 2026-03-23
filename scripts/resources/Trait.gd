extends Resource
class_name Trait

## Trait resource — defines an intrinsic character trait loaded from JSON.
## Traits are permanent and cannot be traded or removed by normal means.
## Use TraitDatabase.get_trait(id) to retrieve by id.

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
## Arbitrary tags for filtering and combat interactions (e.g. "curse", "beast", "positive").
@export var tags: Array[String] = []

## Create a Trait from a JSON-parsed Dictionary.
static func create_from_dict(data: Dictionary) -> Trait:
	var t := Trait.new()
	t.id          = str(data.get("id", ""))
	t.name        = str(data.get("name", ""))
	t.description = str(data.get("description", ""))
	t.icon_path   = str(data.get("icon", ""))
	var raw_tags = data.get("tags", [])
	if raw_tags is Array:
		for tag in raw_tags:
			t.tags.append(str(tag))
	return t
