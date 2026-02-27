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

# Fourteen moon phases (Sprite2D frames 0-13); cycle repeats every (14 * days_per_lunar_phase) days
# Order: full → waning gibbous (early/late) → last quarter (early/late) → waning crescent (early/late)
# → new moon → waxing crescent (early/late) → first quarter (early/late) → waxing gibbous (early/late)
const LUNAR_FRAME_COUNT: int = 14

# Player-facing labels (early/late collapsed). Index = frame_index (0-13).
const LUNAR_DISPLAY_LABELS: Array[String] = [
	"Full Moon",           # 0
	"Waning Gibbous",      # 1 early
	"Waning Gibbous",      # 2 late
	"Last Quarter",        # 3 early
	"Last Quarter",        # 4 late
	"Waning Crescent",     # 5 early
	"Waning Crescent",     # 6 late
	"New Moon",            # 7
	"Waxing Crescent",     # 8 early
	"Waxing Crescent",     # 9 late
	"First Quarter",       # 10 early
	"First Quarter",       # 11 late
	"Waxing Gibbous",      # 12 early
	"Waxing Gibbous"       # 13 late
]

# Map frame index (0-13) to display-phase index for ProjectColors.LUNAR_PHASE_COLORS (0-7)
const FRAME_TO_COLOR_INDEX: Array[int] = [
	4, 5, 5, 6, 6, 7, 7, 0, 1, 1, 2, 2, 3, 3  # full, w.gibb x2, l.quarter x2, w.crescent x2, new, w.crescent x2, f.quarter x2, w.gibb x2
]

@export var game_time_per_day: float = 1.0
@export var days_per_month: int = 30
@export var months_per_year: int = 12
@export var days_per_lunar_phase: int = 3  # Days per sub-phase (14 sub-phases per full cycle)

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var lunar_cycle_icon: Sprite2D = $MarginContainer/VBoxContainer/Control/MarginContainer/HBoxContainer/LunarCycleIcon/Sprite2D
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
	_set_lunar_phase(total_days)





func _set_lunar_phase(total_days: int) -> void:
	if LUNAR_DISPLAY_LABELS.is_empty() or days_per_lunar_phase <= 0:
		return
	var cycle_length: int = LUNAR_FRAME_COUNT * days_per_lunar_phase
	var day_in_cycle: int = total_days % cycle_length
	var frame_index: int = (day_in_cycle / days_per_lunar_phase) % LUNAR_FRAME_COUNT

	if lunar_cycle_label and frame_index < LUNAR_DISPLAY_LABELS.size():
		lunar_cycle_label.text = LUNAR_DISPLAY_LABELS[frame_index]
		lunar_cycle_label.modulate = _get_lunar_modulate(frame_index)

	if lunar_cycle_icon:
		lunar_cycle_icon.frame = frame_index


func _get_lunar_modulate(frame_index: int) -> Color:
	if ProjectColors.LUNAR_PHASE_COLORS.is_empty():
		return Color.WHITE
	var color_index: int = FRAME_TO_COLOR_INDEX[frame_index % FRAME_TO_COLOR_INDEX.size()] if frame_index < FRAME_TO_COLOR_INDEX.size() else 0
	return ProjectColors.LUNAR_PHASE_COLORS[color_index % ProjectColors.LUNAR_PHASE_COLORS.size()]
