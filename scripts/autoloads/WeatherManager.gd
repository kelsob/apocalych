extends Node

## Global weather for the party. **Weather does not change when traveling** — only **`set_weather`** (events / debug) changes it.
## Data: `res://data/weather/weather_types.json`, `biome_weather.json` (tables reserved for future non-travel systems).
## TagManager adds `weather:<id>` during `refresh_tags()` for event prereqs.
## Combat: `get_active_combat_weather_modifiers()` is a stub (returns []) until modifiers are implemented.

signal weather_changed(snapshot: Dictionary)

## Set **false** in the inspector (autoload) or in code to silence **`WEATHER …`** prints.
@export var debug_log_weather: bool = true

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Monotonic counter for log correlation (emits / map updates).
var _weather_debug_seq: int = 0
## weather_id -> Dictionary (from JSON)
var _weather_types: Dictionary = {}
## biome_name_lower -> Array of { weather_id, weight }
var _biome_tables: Dictionary = {}

var _current_weather_id: String = ""
var _current_biome_key: String = ""


func _ready() -> void:
	_rng.randomize()
	_load_tables()
	_apply_weather_id("clear", "game_start")
	if debug_log_weather:
		print("WEATHER manager ready | types=%d biomes=%d initial_weather=clear" % [_weather_types.size(), _biome_tables.size()])


func _wlog(msg: String) -> void:
	if debug_log_weather:
		print("WEATHER %s" % msg)


func _load_tables() -> void:
	_weather_types.clear()
	_biome_tables.clear()

	var types_path := "res://data/weather/weather_types.json"
	var tf := FileAccess.open(types_path, FileAccess.READ)
	if not tf:
		push_error("WeatherManager: missing %s" % types_path)
		_register_fallback_types()
	else:
		var tj := JSON.new()
		if tj.parse(tf.get_as_text()) != OK:
			push_error("WeatherManager: parse error %s" % types_path)
			_register_fallback_types()
		else:
			var tdata: Variant = tj.data
			if tdata is Array:
				for row in tdata:
					if row is Dictionary and row.has("id"):
						_weather_types[str(row.id)] = row
			else:
				push_error("WeatherManager: weather_types.json root must be array")
				_register_fallback_types()

	var biome_path := "res://data/weather/biome_weather.json"
	var bf := FileAccess.open(biome_path, FileAccess.READ)
	if not bf:
		push_error("WeatherManager: missing %s" % biome_path)
		_biome_tables["default"] = [{ "weather_id": "clear", "weight": 100 }]
	else:
		var bj := JSON.new()
		if bj.parse(bf.get_as_text()) != OK:
			push_error("WeatherManager: parse error %s" % biome_path)
			_biome_tables["default"] = [{ "weather_id": "clear", "weight": 100 }]
		else:
			var bdata: Variant = bj.data
			if bdata is Dictionary:
				for k in bdata.keys():
					_biome_tables[str(k).strip_edges().to_lower()] = bdata[k]
			else:
				_biome_tables["default"] = [{ "weather_id": "clear", "weight": 100 }]

	if not _biome_tables.has("default"):
		_biome_tables["default"] = [{ "weather_id": "clear", "weight": 100 }]


func _register_fallback_types() -> void:
	_weather_types = {
		"clear": { "id": "clear", "display_name": "Clear", "icon": "", "combat_effect_ids": [] },
	}


## Call when the party arrives on a map node. Updates **`_current_biome_key`** for UI/snapshots only — **does not change weather**.
func sync_biome_from_node(node: MapNode2D) -> void:
	_weather_debug_seq += 1
	var seq: int = _weather_debug_seq
	var node_label: String = "null"
	if node != null:
		node_label = "%s" % node.name
	var prev_biome: String = _current_biome_key
	var biome_key := "default"
	if node != null and node.biome != null:
		biome_key = str(node.biome.biome_name).strip_edges().to_lower()
	_current_biome_key = biome_key
	_wlog("sync_biome #%d node=%s weather_id=%s (unchanged) biome %s→%s" % [
		seq, node_label, _current_weather_id, prev_biome, biome_key
	])


## Unused while travel does not roll weather; kept for a future system (e.g. camp/rest).
func _pick_weighted_weather(entries: Array, seq: int = -1) -> String:
	var total: float = 0.0
	for e in entries:
		if e is Dictionary:
			total += float(e.get("weight", 1))
	if total <= 0.0:
		_wlog("pick #%d total_weight<=0 → clear" % seq)
		return "clear"
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	var detail: PackedStringArray = PackedStringArray()
	for e in entries:
		if e is Dictionary:
			var w: float = float(e.get("weight", 1))
			var wid: String = str(e.get("weather_id", "clear"))
			acc += w
			if debug_log_weather and seq >= 0:
				detail.append("%s:%.1f→%.1f" % [wid, w, acc])
			if roll <= acc:
				if debug_log_weather and seq >= 0:
					_wlog("pick #%d roll=%.4f / total=%.4f [%s] → %s" % [
						seq, roll, total, ", ".join(detail), wid
					])
				return wid
	var last: String = str((entries[entries.size() - 1] as Dictionary).get("weather_id", "clear"))
	_wlog("pick #%d fell through (precision?) → %s" % [seq, last])
	return last


func _apply_weather_id(weather_id: String, source: String = "") -> void:
	var wid: String = str(weather_id).strip_edges()
	if wid.is_empty():
		wid = "clear"
	if not _weather_types.has(wid):
		push_warning("WeatherManager: unknown weather id '%s', using clear" % wid)
		wid = "clear"
	var before: String = _current_weather_id
	if before == wid:
		_wlog("apply skip (unchanged id=%s) source=%s — no signal" % [wid, source])
		return
	_current_weather_id = wid
	var snap: Dictionary = get_weather_snapshot()
	_wlog("apply %s → %s (biome_key=%s) source=%s | emitting weather_changed" % [
		before, wid, _current_biome_key, source
	])
	weather_changed.emit(snap)


func get_current_weather_id() -> String:
	return _current_weather_id


func get_current_biome_key() -> String:
	return _current_biome_key


## UI + debug: stable keys for a panel (`icon` may be empty until you assign art).
func get_weather_snapshot() -> Dictionary:
	var row: Dictionary = _weather_types.get(_current_weather_id, {}) as Dictionary
	var effect_ids: Array = []
	var raw_fx: Variant = row.get("combat_effect_ids", [])
	if raw_fx is Array:
		effect_ids = raw_fx.duplicate()
	var summary: String = "No combat effects."
	if not effect_ids.is_empty():
		var bits: PackedStringArray = PackedStringArray()
		for x in effect_ids:
			bits.append(str(x))
		summary = "Combat effects: %s (not applied yet)" % ", ".join(bits)

	return {
		"id": _current_weather_id,
		"display_name": str(row.get("display_name", _current_weather_id.capitalize())),
		"icon": str(row.get("icon", "")),
		"biome_key": _current_biome_key,
		"combat_effect_ids": effect_ids,
		"effects_summary": summary,
	}


## Hook for CombatController — return modifier payloads/resources when implemented. Always [] for now.
func get_active_combat_weather_modifiers() -> Array:
	if _current_weather_id.is_empty():
		return []
	var row: Dictionary = _weather_types.get(_current_weather_id, {}) as Dictionary
	var raw: Variant = row.get("combat_effect_ids", [])
	if raw is Array and not raw.is_empty():
		# Reserved: load/return CombatWeatherModifier resources by id.
		pass
	return []


## Scripted / event effects: set current weather (validated against `weather_types.json`). Emits **`weather_changed`**; UI and `TagManager` should refresh.
func set_weather(weather_id: String) -> void:
	_wlog("set_weather(%s) called" % str(weather_id))
	_apply_weather_id(weather_id, "set_weather")


## Same as **`set_weather`** (debug consoles / tests).
func debug_set_weather(weather_id: String) -> void:
	set_weather(weather_id)
