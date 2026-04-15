extends RefCounted
class_name DamagePacket

## Immutable-ish description of a single damage application. Passed through CombatDamageResolver
## before shields and HP are touched.

var base_amount: float = 0.0
var category: CombatDamageKind.Kind = CombatDamageKind.Kind.PHYSICAL
## When true, physical damage skips subtracting `def` (e.g. bleed). Magical still uses `mag_def` unless changed later.
var bypass_physical_mitigation: bool = false


static func make(amount: float, category: CombatDamageKind.Kind, bypass_physical: bool = false) -> DamagePacket:
	var p := DamagePacket.new()
	p.base_amount = amount
	p.category = category
	p.bypass_physical_mitigation = bypass_physical
	return p


## Legacy-style physical hit (abilities that only specify potency).
static func physical_simple(amount: float) -> DamagePacket:
	return make(amount, CombatDamageKind.Kind.PHYSICAL, false)


## Status ticks and similar: physical DoT with optional armour bypass.
static func physical_status_tick(amount: float, bypass_armour: bool) -> DamagePacket:
	return make(amount, CombatDamageKind.Kind.PHYSICAL, bypass_armour)
