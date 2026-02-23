extends Resource
class_name Class

## Class resource - defines a character class with abilities and stat modifiers

@export var name: String = ""
@export var description: String = ""
@export var weapon_type: String = "Weapon"  # e.g. "Bow", "Sword" — used for display (e.g. "Jeff's Copper Bow")
@export var stat_modifiers: Dictionary = {}  # e.g., {"strength": 2, "intelligence": -1, ...}
@export var abilities: Array[Ability] = []  # Combat abilities for this class
@export var rest_abilities: Array[RestAbility] = []  ## 2 rest abilities from class
