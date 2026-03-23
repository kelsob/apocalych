extends Control

## Shows current weather from WeatherManager; drives `Sprite2D` frame on `weather-icons.png`.
## Sheet frames: 0 clear, 1 cloudy, 2 rainy, 3 windy, 4 lightning storm, 5 snow.

@onready var weather_icon_sprite: Sprite2D = $Sprite2D

## Weather ids with a 1:1 frame on the sheet.
const WEATHER_TO_FRAME: Dictionary = {
	"clear": 0,
	"cloudy": 1,
	"rainy": 2,
	"windy": 3,
	"thunderstorms": 4,
	"snow": 5,
}

## No dedicated frame yet — temporary stand-ins (change when you add art).
const WEATHER_FRAME_FALLBACK: Dictionary = {
	"foggy": 1,
	"hail": 5,
	"ashen_rain": 2,
	"sea_mist": 1,
	"heat_wave": 0,
}

var _on_weather_changed_cb: Callable
var _last_applied_weather_id: String = ""


func _ready() -> void:
	_on_weather_changed_cb = Callable(self, "_on_weather_changed")
	var already: bool = WeatherManager.weather_changed.is_connected(_on_weather_changed_cb)
	if not already:
		WeatherManager.weather_changed.connect(_on_weather_changed_cb)
	if WeatherManager.debug_log_weather:
		var mgr_id: String = str(WeatherManager.get_instance_id())
		print("WEATHER UI ready inst=%s parent=%s | weather_changed connected=%s (was_already=%s) | mgr_node=%s" % [
			str(get_instance_id()),
			str(get_parent().name) if get_parent() else "null",
			str(WeatherManager.weather_changed.is_connected(_on_weather_changed_cb)),
			str(already),
			mgr_id
		])
	call_deferred("_sync_from_manager")


func _exit_tree() -> void:
	if WeatherManager.weather_changed.is_connected(_on_weather_changed_cb):
		WeatherManager.weather_changed.disconnect(_on_weather_changed_cb)
		if WeatherManager.debug_log_weather:
			print("WEATHER UI exit_tree inst=%s disconnected weather_changed" % str(get_instance_id()))


func _on_weather_changed(snapshot: Dictionary) -> void:
	if WeatherManager.debug_log_weather:
		var sid: String = str(snapshot.get("id", "?"))
		var bf: int = weather_icon_sprite.frame if weather_icon_sprite else -9
		print("WEATHER UI signal inst=%s | snapshot.id=%s snapshot.biome_key=%s sprite.frame(before)=%s" % [
			str(get_instance_id()), sid, str(snapshot.get("biome_key", "?")), str(bf)
		])
	_apply_snapshot(snapshot, "signal")


func _sync_from_manager() -> void:
	if WeatherManager.debug_log_weather:
		print("WEATHER UI deferred_sync inst=%s | calling get_weather_snapshot()" % str(get_instance_id()))
	_apply_snapshot(WeatherManager.get_weather_snapshot(), "deferred_sync")


func _apply_snapshot(snapshot: Dictionary, source: String) -> void:
	var weather_id: String = str(snapshot.get("id", "clear"))
	var display: String = str(snapshot.get("display_name", weather_id))
	var frame_idx: int = int(WEATHER_TO_FRAME.get(weather_id, -1))
	var used_fallback: bool = false
	if frame_idx < 0:
		frame_idx = int(WEATHER_FRAME_FALLBACK.get(weather_id, 0))
		used_fallback = true

	var prev_frame: int = -1
	if weather_icon_sprite != null:
		prev_frame = weather_icon_sprite.frame
		if weather_id == _last_applied_weather_id and frame_idx == prev_frame:
			if WeatherManager.debug_log_weather:
				print("WEATHER UI skip no-op inst=%s source=%s id=%s frame=%s (already shown)" % [
					str(get_instance_id()), source, weather_id, str(frame_idx)
				])
			return
		weather_icon_sprite.frame = frame_idx

	_last_applied_weather_id = weather_id
	tooltip_text = "Weather: %s" % display

	if WeatherManager.debug_log_weather:
		print("WEATHER UI apply inst=%s source=%s | id=%s display=%s frame %s→%s fallback=%s keys=%s" % [
			str(get_instance_id()),
			source,
			weather_id,
			display,
			str(prev_frame),
			str(frame_idx),
			str(used_fallback),
			str(snapshot.keys())
		])
