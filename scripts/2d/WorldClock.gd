extends Control

## WorldClock - Displays current world date using a fantasy (Elvish) calendar.
## Does not control time; TimeManager advances time. Progress bar reserved for world-demise progress (left blank).
## Days: six-day week from Tolkien's Reckoning of Rivendell (Quenya). Months: twelve from Kings' Reckoning (Quenya).

# Six-day week (Reckoning of Rivendell) - Quenya (unaccented for font compatibility)
const DAY_NAMES: Array[String] = [
	"Elenya",   # Stars
	"Anarya",   # Sun
	"Isilya",   # Moon
	"Alduya",   # Two Trees
	"Menelya",  # Heavens
	"Valanya"   # Valar / Powers
]

# Twelve months (Kings' Reckoning / Numerorean calendar) - Quenya (unaccented)
const MONTH_NAMES: Array[String] = [
	"Narvinye", "Nenime", "Sulime", "Viresse", "Lotesse", "Nare",
	"Cermie", "Urime", "Yavannie", "Narquelie", "Hisime", "Ringare"
]

# Eight moon phases in order; cycle repeats every (8 * days_per_lunar_phase) days
const MOON_PHASES: Array[String] = [
	"New Moon",
	"Waxing Crescent",
	"First Quarter",
	"Waxing Gibbous",
	"Full Moon",
	"Waning Gibbous",
	"Last Quarter",
	"Waning Crescent"
]

@export var game_time_per_day: float = 1.0
@export var days_per_month: int = 30
@export var months_per_year: int = 12
@export var days_per_lunar_phase: int = 3

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var date_label: Label = $MarginContainer/VBoxContainer/DateLabel
@onready var lunar_cycle_label: Label = $MarginContainer/VBoxContainer/LunarCycleLabel

func _ready() -> void:
	# Progress bar left blank for world-demise progress; do not set value here.
	if progress_bar:
		progress_bar.show_percentage = false
		progress_bar.value = 0
		progress_bar.min_value = 0
		progress_bar.max_value = 1
	_refresh_from_time_manager()

	var tm_node = get_node_or_null("/root/TimeManager")
	if tm_node and tm_node.has_signal("time_advanced"):
		tm_node.time_advanced.connect(_on_time_advanced)


func _on_time_advanced(_amount: float, _new_total: float) -> void:
	_refresh_from_time_manager()


func _refresh_from_time_manager() -> void:
	var tm = get_node_or_null("/root/TimeManager") as Node
	if not tm or not "game_time" in tm:
		return
	var total_days: float = tm.game_time / game_time_per_day
	set_calendar_from_total_days(int(total_days))


## Set the displayed date from total elapsed days (0-based).
## Derives day-of-week (6-day), day-of-month, month, year, and moon phase.
func set_calendar_from_total_days(total_days: int) -> void:
	var days_in_year: int = days_per_month * months_per_year
	var year: int = total_days / days_in_year if days_in_year > 0 else 0
	var day_of_year: int = total_days % days_in_year if days_in_year > 0 else 0
	var month: int = (day_of_year / days_per_month) % months_per_year if days_per_month > 0 else 0
	var day_of_month: int = (day_of_year % days_per_month) + 1
	var day_of_week: int = total_days % DAY_NAMES.size()
	set_calendar_date(day_of_week, day_of_month, month, year)
	_set_lunar_phase(total_days)


## Set the displayed date from explicit calendar values.
## day_of_week: 0–5 (Elenya … Valanya). month: 0–11. day_of_month: 1–days_per_month.
func set_calendar_date(day_of_week: int, day_of_month: int, month: int, year: int) -> void:
	if not date_label:
		return
	var day_name: String = DAY_NAMES[day_of_week % DAY_NAMES.size()]
	var month_name: String = MONTH_NAMES[month % MONTH_NAMES.size()]
	date_label.text = "%s, %s the %d — Year %d" % [day_name, month_name, day_of_month, year]


func _set_lunar_phase(total_days: int) -> void:
	if not lunar_cycle_label or MOON_PHASES.is_empty() or days_per_lunar_phase <= 0:
		return
	var cycle_length: int = MOON_PHASES.size() * days_per_lunar_phase
	var day_in_cycle: int = total_days % cycle_length
	var phase_index: int = (day_in_cycle / days_per_lunar_phase) % MOON_PHASES.size()
	lunar_cycle_label.text = MOON_PHASES[phase_index]
