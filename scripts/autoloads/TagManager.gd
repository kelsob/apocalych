extends Node

## Central tag source for events and UI. Tags drive EventManager prereqs (requires_tags, etc.).
##
## • **Derived tags** — rebuilt every `refresh_tags()`: race/class, traits, biome, weather, lunar, item presence.
## • **Items (segmented)** — `char_item:<id>` = on a member; `resource:<id>` = party stash bulk count > 0;
##   `item:<id>` = union of both (backward compatible). **Gold is not a tag** — use EventManager `prereqs.min_gold` / `max_gold` / `party_resources` with `"id": "gold"`.
## • **Event outcome tags** — appended by `add_tag` / `remove_tag` when an event resolves; kept until removed.
##   Same pool at query time: `get_all_tags()` = derived ∪ outcome (e.g. `warg_ambush_fled` + follow-up `requires_tags`).
##
## Call `refresh_tags()` before event picks (`EventManager`) and when party/gold changes (`Main.update_tags_from_party`).

signal tags_changed()

## Tags added by event effects (`add_tag`). Not cleared by `refresh_tags()` (only derived tags are rebuilt).
var event_outcome_tags: Array[String] = []

## Last computed-only snapshot (for debugging).
var _computed_tags: Array[String] = []

func _find_main_node() -> Node:
	var root: Window = get_tree().root if get_tree() else null
	if not root:
		return null
	for c in root.get_children():
		if c.name == "Main" or c.is_in_group("main"):
			return c
	return null

func _append_unique_computed(s: String) -> void:
	if s.is_empty():
		return
	if not _computed_tags.has(s):
		_computed_tags.append(s)


func _append_weather_tag_from_manager() -> void:
	var root: Window = get_tree().root if get_tree() else null
	if root == null:
		return
	var wm: Node = root.get_node_or_null("WeatherManager")
	if wm == null or not wm.has_method("get_current_weather_id"):
		return
	var wid: String = str(wm.call("get_current_weather_id"))
	if wid.is_empty():
		return
	_append_unique_computed("weather:%s" % wid)

## Rebuild derived tags from party, inventory, traits, biome, weather, TimeManager. `party_gold` is unused (kept for call-site compatibility).
## `event_outcome_tags` unchanged; `get_all_tags()` merges derived + outcome lists.
func refresh_tags(main: Node, party_members: Variant, _party_gold: int, biome: String) -> void:
	_computed_tags.clear()
	var members: Array = []
	if party_members is Array:
		members = party_members
	if members.is_empty():
		tags_changed.emit()
		return

	var race_counts: Dictionary = {}
	var class_counts: Dictionary = {}
	for m in members:
		if not m is HeroCharacter:
			continue
		if m.race:
			var race_key: String = m.race.race_name.to_lower()
			race_counts[race_key] = int(race_counts.get(race_key, 0)) + 1
		if m.class_resource:
			var class_key: String = m.class_resource.name.to_lower()
			class_counts[class_key] = int(class_counts.get(class_key, 0)) + 1

	for race_key in race_counts:
		_append_unique_computed("<%s>" % race_key)
		if int(race_counts[race_key]) == members.size():
			_append_unique_computed("<all_%s>" % race_key)

	for class_key in class_counts:
		_append_unique_computed("<%s>" % class_key)
		if int(class_counts[class_key]) == members.size():
			_append_unique_computed("<all_%s>" % class_key)

	for m in members:
		if not m is HeroCharacter:
			continue
		if m.hero_id and not m.hero_id.is_empty():
			_append_unique_computed("hero:%s" % m.hero_id)
		for tid in m.get_trait_ids():
			_append_unique_computed("trait:%s" % tid)
		for item_id in m.get_inventory_ids():
			var iid: String = str(item_id)
			_append_unique_computed("char_item:%s" % iid)
			_append_unique_computed("item:%s" % iid)

	# Party-wide bulk resources on Main (health_potion, camping_supplies, …) — not on HeroCharacter inventory
	if main != null and "party_resources" in main:
		var pr: Variant = main.party_resources
		if pr is Dictionary:
			for res_key in pr.keys():
				if int(pr[res_key]) > 0:
					var rk: String = str(res_key)
					_append_unique_computed("resource:%s" % rk)
					_append_unique_computed("item:%s" % rk)

	var bio: String = str(biome).strip_edges().to_lower()
	if not bio.is_empty():
		_append_unique_computed("biome:%s" % bio)

	_append_weather_tag_from_manager()

	if TimeManager:
		for lunar_tag in TimeManager.get_lunar_tags():
			_append_unique_computed(lunar_tag)

	tags_changed.emit()

## Back-compat: refresh from party only (no biome); pulls gold from Main when available.
func update_tags_from_party(party_members: Array[HeroCharacter]) -> void:
	var main: Node = _find_main_node()
	var gold: int = int(main.party_gold) if main and "party_gold" in main else 0
	refresh_tags(main, party_members, gold, "")

func get_all_tags() -> Array[String]:
	var out: Array[String] = []
	for t in _computed_tags:
		if not out.has(t):
			out.append(t)
	for t in event_outcome_tags:
		if not out.has(t):
			out.append(t)
	return out

func get_computed_tags() -> Array[String]:
	return _computed_tags.duplicate()

func get_event_outcome_tags() -> Array[String]:
	return event_outcome_tags.duplicate()

func has_tag(tag: String) -> bool:
	return get_all_tags().has(tag)

func has_any_tag(tags: Array[String]) -> bool:
	var all := get_all_tags()
	for tag in tags:
		if all.has(tag):
			return true
	return false

func has_all_tags(tags: Array[String]) -> bool:
	var all := get_all_tags()
	for tag in tags:
		if not all.has(tag):
			return false
	return true

func add_tag(tag: String) -> void:
	if tag.is_empty():
		return
	if not event_outcome_tags.has(tag):
		event_outcome_tags.append(tag)
		tags_changed.emit()

func remove_tag(tag: String) -> void:
	var index: int = event_outcome_tags.find(tag)
	if index >= 0:
		event_outcome_tags.remove_at(index)
		tags_changed.emit()

## Clears only tags added by events (`add_tag` / `remove_tag` layer).
func clear_event_outcome_tags() -> void:
	event_outcome_tags.clear()
	tags_changed.emit()

## Clears outcome + derived (e.g. new game). Next `refresh_tags` repopulates derived.
func clear_all_tags() -> void:
	event_outcome_tags.clear()
	_computed_tags.clear()
	tags_changed.emit()

## Deprecated alias — clears event outcome tags only.
func clear_tags() -> void:
	clear_event_outcome_tags()
