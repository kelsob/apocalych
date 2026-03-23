extends Node

## TimeManager - Global time progression tracking for the world
## All player actions and events can advance world time.
## Future: Scaling events, difficulty, and time-based world occurrences.

signal time_advanced(amount: float, new_total: float)

## Accumulated world time. Interpret as minutes, hours, or days as needed.
var game_time: float = 0.0

## How much game time advances per pixel of map travel distance.
## Higher = more time per pixel (longer journeys in game terms).
@export var time_per_pixel: float = 0.05


func _ready():
	pass


## Advance time by a raw amount.
func advance_time(amount: float) -> void:
	if amount <= 0.0:
		return
	var previous_total := game_time
	game_time += amount
	print("[TimeManager] Time advanced: +%.2f (%.2f -> %.2f)" % [amount, previous_total, game_time])
	time_advanced.emit(amount, game_time)


## Advance time based on rest duration. Quick=1, Medium=2, Long=3 units.
func advance_time_from_rest(time_units: float) -> void:
	if time_units <= 0.0:
		return
	print("[TimeManager] Rest: %.0f unit(s) -> +%.1f world time" % [time_units, time_units])
	advance_time(time_units)


## Advance time based on combat duration. Uses the combat timeline's global_time (turn-based clock).
## Optional turn_count for debug output.
func advance_time_from_combat(combat_duration: float, turn_count: int = -1) -> void:
	if combat_duration <= 0.0:
		return
	if turn_count >= 0:
		print("[TimeManager] Combat: %.2f combat-time (%d turns) -> +%.2f world time" % [combat_duration, turn_count, combat_duration])
	else:
		print("[TimeManager] Combat: %.2f combat-time -> +%.2f world time" % [combat_duration, combat_duration])
	advance_time(combat_duration)


## Advance time from an event choice effect. Used for narrative consequences (e.g. punishment for a bad choice).
func advance_time_from_event(amount: float) -> void:
	if amount <= 0.0:
		return
	print("[TimeManager] Event: +%.1f world time" % amount)
	advance_time(amount)


## Advance time based on map travel. Path distance is in pixels (map coordinates).
func advance_time_from_travel(path_distance_pixels: float) -> void:
	if path_distance_pixels <= 0.0:
		return
	var time_amount: float = path_distance_pixels * time_per_pixel
	print("[TimeManager] Travel: %.1f px @ %.4f time/pixel = +%.2f time" % [path_distance_pixels, time_per_pixel, time_amount])
	advance_time(time_amount)


## Reset time (e.g. when starting a new game).
func reset_time() -> void:
	print("[TimeManager] Time reset (was %.2f)" % game_time)
	game_time = 0.0


# --- Lunar cycle (abstract game-time phases; not tied to real calendar) ---
## Length of one full lunar cycle in arbitrary time units (same units as game_time).
@export var lunar_cycle_length: float = 6720.0

const _LUNAR_NAMES: Array[String] = [
	"new", "waxing_crescent", "first_quarter", "waxing_gibbous",
	"full", "waning_gibbous", "third_quarter", "waning_crescent"
]

## 0 .. 7 index into _LUNAR_NAMES
func get_lunar_phase_index() -> int:
	if lunar_cycle_length <= 0.0:
		return 0
	var t: float = fposmod(game_time, lunar_cycle_length)
	var segment: float = lunar_cycle_length / 8.0
	return int(t / segment) % 8

func get_lunar_phase_name() -> String:
	return _LUNAR_NAMES[get_lunar_phase_index()]

## Tags for TagManager / events: lunar:<phase> plus lunar:any
func get_lunar_tags() -> Array[String]:
	var name: String = get_lunar_phase_name()
	return ["lunar:%s" % name, "lunar:any"]

