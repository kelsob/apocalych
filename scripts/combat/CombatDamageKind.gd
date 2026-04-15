extends Object
class_name CombatDamageKind

## Shared vocabulary for damage classification. Used by DamagePacket, AbilityEffect, StatusEffect,
## and CombatDamageResolver. Extend this enum when adding elements/poison/etc. at a higher tier.

enum Kind {
	PHYSICAL, ## Reduced by flat physical mitigation (`def` / armour)
	MAGICAL, ## Reduced by `mag_def`
	TRUE, ## Ignores def and mag_def; still subject to creature-tag rules where explicitly coded
}
