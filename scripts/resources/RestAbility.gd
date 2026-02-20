extends Resource
class_name RestAbility

## RestAbility - Defines a rest ability from race (1) or class (2)
## Placeholder: no actual effect yet; wired for future functionality

enum DurationAvailability {
	ALL,         ## Available for quick, medium, and long rest
	MEDIUM_LONG, ## Available for medium and long rest only
	LONG         ## Available for long rest only
}

@export var ability_name: String = ""
@export var ability_id: String = ""
@export var description: String = ""

## Which rest durations this ability can be used during
@export var available_durations: DurationAvailability = DurationAvailability.ALL

## Check if this ability is available for the given rest duration
func is_available_for_duration(duration: int) -> bool:
	match available_durations:
		DurationAvailability.ALL:
			return true
		DurationAvailability.MEDIUM_LONG:
			return duration >= 1  # 1 = medium, 2 = long
		DurationAvailability.LONG:
			return duration == 2  # 2 = long only
	return false
