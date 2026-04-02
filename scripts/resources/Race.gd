extends Resource
class_name Race

## Race resource - defines a character race with base stats and properties

@export var race_name: String = ""
@export var description: String = ""
@export var base_stats: Dictionary = {}  # strength, agility, constitution, intellect, spirit, charisma, luck
@export var rest_ability: RestAbility = null  ## 1 rest ability from race
@export var portrait_1: Texture2D = null
@export var portrait_2: Texture2D = null
@export var combat_portrait_1: Texture2D = null
@export var combat_portrait_2: Texture2D = null
