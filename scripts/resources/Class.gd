extends Resource
class_name Class

## Class resource - defines a character class with abilities and stat modifiers

@export var name: String = ""
@export var description: String = ""
@export var weapon_type: String = "Weapon"  # e.g. "Bow", "Sword" — used for display (e.g. "Jeff's Copper Bow")
@export var armour_type: String = "Armour"  # e.g. "Tunic", "Plate", "Robes" — used for display (e.g. "Jeff's Copper Plate")
## Initial combat row when [member HeroCharacter.use_class_default_formation] is true (0 = Front, 1 = Back).
@export_enum("Front", "Back") var default_combat_formation_row: int = 0
## When empty or incomplete, legacy [member stat_modifiers] + race [member Race.base_stats] apply. Prefer full [member stat_spread] (all seven keys, values 5–10): one 5 and one 10 per class is the usual shape.
@export var stat_spread: Dictionary = {}
## Legacy additive modifiers when [member stat_spread] is not used.
@export var stat_modifiers: Dictionary = {}  # strength, agility, constitution, intellect, spirit, charisma, luck
## Key in [member HeroCharacter.PRIMARY_STAT_KEYS]. Player basic-attack damage is [code]final_primary × rate[/code] via [method HeroCharacter.get_basic_attack_damage_from_primary_stat]. Avoid constitution / luck for this.
@export var basic_attack_primary_stat: String = "strength"
## Multiplier on the class primary stat: damage = [code]stat × rate[/code] (e.g. AGI 8 and [code]0.5[/code] → 4).
@export var basic_attack_stat_scaling_rate: float = 1.0
@export var abilities: Array[Ability] = []  # Combat abilities for this class
@export var rest_abilities: Array[RestAbility] = []  ## 2 rest abilities from class
