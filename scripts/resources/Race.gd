extends Resource
class_name Race

## Race resource - defines a character race with base stats and properties

@export var race_name: String = ""
@export var description: String = ""
@export var base_stats: Dictionary = {}  # e.g., {"strength": 10, "intelligence": 8, ...}
@export var rest_ability: RestAbility = null  ## 1 rest ability from race
