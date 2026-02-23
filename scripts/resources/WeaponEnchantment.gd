extends Resource
class_name WeaponEnchantment

## WeaponEnchantment - Modifier applied to a weapon via enchantment slot
## Extend with more stat modifiers as needed

@export var id: String = ""
@export var display_name: String = ""
@export var damage_bonus: int = 0
## Future: @export var stat_modifiers: Dictionary = {}
