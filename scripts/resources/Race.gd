extends Resource
class_name Race

## Race resource - defines a character race with base stats and properties

@export var race_name: String = ""
@export var description: String = ""
## Legacy: only used when a class has no [member Class.stat_spread]. Prefer [member stat_adjustments] for new heroes.
@export var base_stats: Dictionary = {}  # strength, agility, constitution, intellect, spirit, charisma, luck
## Applied after class [member Class.stat_spread] (additive; not clamped). Typical values -1, 0, +1.
@export var stat_adjustments: Dictionary = {}
## Flat bonus to [member HeroCharacter.get_initiative] for this race (combat timeline).
@export var initiative_bonus: int = 0
@export var rest_ability: RestAbility = null  ## 1 rest ability from race
@export var portrait_1: Texture2D = null
@export var portrait_2: Texture2D = null
@export var combat_portrait_1: Texture2D = null
@export var combat_portrait_2: Texture2D = null
