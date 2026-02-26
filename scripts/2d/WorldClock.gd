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

# Icon paths per phase index
const MOON_ICON_PATHS: Array[String] = [
	"res://assets/map/moon/new-moon.png",
	"res://assets/map/moon/waxing-crescent.png",
	"res://assets/map/moon/half-moon-first-quarter.png",
	"res://assets/map/moon/waxing-gibbous.png",
	"res://assets/map/moon/full-moon.png",
	"res://assets/map/moon/waning-gibbous.png",
	"res://assets/map/moon/half-moon-last-quarter.png",
	"res://assets/map/moon/waning-crescent.png"
]

@export var game_time_per_day: float = 1.0
@export var days_per_month: int = 30
@export var months_per_year: int = 12
@export var days_per_lunar_phase: int = 3

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var date_label: Label = $MarginContainer/VBoxContainer/DateLabel
@onready var lunar_cycle_icon: TextureRect = $MarginContainer/VBoxContainer/Control/MarginContainer/HBoxContainer/LunarCycleIcon
@onready var lunar_cycle_label: Label = $MarginContainer/VBoxContainer/Control/MarginContainer/HBoxContainer/LunarCycleLabel

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
## Date label may be hidden; we still track internally.
func set_calendar_date(day_of_week: int, day_of_month: int, month: int, year: int) -> void:
	if date_label:
		var day_name: String = DAY_NAMES[day_of_week % DAY_NAMES.size()]
		var month_name: String = MONTH_NAMES[month % MONTH_NAMES.size()]
		date_label.text = "%s, %s the %d — Year %d" % [day_name, month_name, day_of_month, year]


func _set_lunar_phase(total_days: int) -> void:
	if MOON_PHASES.is_empty() or days_per_lunar_phase <= 0:
		return
	var cycle_length: int = MOON_PHASES.size() * days_per_lunar_phase
	var day_in_cycle: int = total_days % cycle_length
	var phase_index: int = (day_in_cycle / days_per_lunar_phase) % MOON_PHASES.size()

	if lunar_cycle_label:
		lunar_cycle_label.text = MOON_PHASES[phase_index]
		lunar_cycle_label.modulate = _get_lunar_modulate(phase_index)

	if lunar_cycle_icon and phase_index < MOON_ICON_PATHS.size():
		var path: String = MOON_ICON_PATHS[phase_index]
		var tex: Texture2D = load(path) as Texture2D if not path.is_empty() else null
		lunar_cycle_icon.texture = tex


func _get_lunar_modulate(phase_index: int) -> Color:
	if ProjectColors.LUNAR_PHASE_COLORS.is_empty():
		return Color.WHITE
	return ProjectColors.LUNAR_PHASE_COLORS[phase_index % ProjectColors.LUNAR_PHASE_COLORS.size()]
