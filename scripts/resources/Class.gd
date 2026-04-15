extends Resource
class_name Class

## Class resource - defines a character class with abilities and stat modifiers

@export var name: String = ""
@export var description: String = ""
@export var weapon_type: String = "Weapon"  # e.g. "Bow", "Sword" — used for display (e.g. "Jeff's Copper Bow")
@export var armour_type: String = "Armour"  # e.g. "Tunic", "Plate", "Robes" — used for display (e.g. "Jeff's Copper Plate")
## Initial combat row when [member HeroCharacter.use_class_default_formation] is true (0 = Front, 1 = Back).
@export_enum("Front", "Back") var default_combat_formation_row: int = 0
@export var stat_modifiers: Dictionary = {}  # strength, agility, constitution, intellect, spirit, charisma, luck
@export var abilities: Array[Ability] = []  # Combat abilities for this class
@export var rest_abilities: Array[RestAbility] = []  ## 2 rest abilities from class
