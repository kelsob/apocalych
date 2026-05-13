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
## UI tint for this class (HUD, banners, framing). Resolved on heroes via [method HeroCharacter.get_class_color].
@export var class_color: Color = Color(0.82, 0.84, 0.88, 1)
## Flat AP modifier applied to both Advance/Retreat while this class is active.
@export var movement_ap_cost_modifier: int = 0
## Optional replacement for the default Advance ability.
@export var default_advance_ability_override: Ability = null
## Optional replacement for the default Retreat ability.
@export var default_retreat_ability_override: Ability = null
## **Combat specials authoring:** Every class `.tres` should define both [member abilities] and [member starting_abilities] (use an empty array when there is no pool yet). Starters must be a subset of the pool and grant **at most three** skills ([member HeroCharacter.MAX_STARTING_CLASS_SPECIAL_ABILITIES]). If [member starting_abilities] is left empty but [member abilities] is not, the first three pool entries are used as a shorthand.
@export var abilities: Array[Ability] = []
## Subset of [member abilities] copied into [member HeroCharacter.unlocked_combat_abilities] on [method HeroCharacter.initialize]. Empty array + empty pool → no class specials; empty array + non-empty pool → first three pool entries ([member HeroCharacter._sync_unlocked_combat_abilities_from_class_defaults]).
@export var starting_abilities: Array[Ability] = []
@export var rest_abilities: Array[RestAbility] = []  ## 2 rest abilities from class
