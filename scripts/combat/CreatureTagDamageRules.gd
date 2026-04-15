extends RefCounted
class_name CreatureTagDamageRules

## Post–stat-mitigation rules keyed off creature tags (`Enemy.TAG_*` via [method Enemy.get_creature_tag_mask]).
## Add a private `_tagname(...)` helper per rule, then invoke it from `_apply_enemy_tags` so interactions
## stay localized and testable.
##
## Pipeline order: `CombatDamageResolver` applies `def` / `mag_def` / TRUE rules first, then this module,
## then shields and HP (`CombatantStats.apply_resolved_hit`).
##
## Future hooks: resistance tables (e.g. Demon vs holy), “boss” flags on Enemy, or party member tags via
## `HeroCharacter` once exposed — keep signatures `(target, category, amount, breakdown) -> float`.

static func apply_after_stat_mitigation(
	target: CombatantData,
	category: CombatDamageKind.Kind,
	amount: float,
	breakdown: Array
) -> float:
	if amount <= 0.0:
		return amount

	var source = target.source
	if source == null:
		return amount

	# Future: HeroCharacter / other sources can expose get_combat_creature_tags() -> int
	if source is Enemy:
		return _apply_enemy_tags(source as Enemy, category, amount, breakdown)

	return amount


static func _apply_enemy_tags(enemy: Enemy, category: CombatDamageKind.Kind, amount: float, breakdown: Array) -> float:
	var tags: int = enemy.get_creature_tag_mask()
	var result: float = amount

	if (tags & Enemy.TAG_SPECTRAL) != 0:
		result = _spectral(result, category, breakdown)

	# Register additional tag handlers above; each should append to `breakdown` when it changes amount.

	return result


## Spectral: highly resistant to physical harm — any positive physical hit after def becomes 1.
## Magical damage uses normal mag_def mitigation only (applied before this runs).
static func _spectral(amount: float, category: CombatDamageKind.Kind, breakdown: Array) -> float:
	if category != CombatDamageKind.Kind.PHYSICAL:
		return amount
	if amount <= 0.0:
		return amount
	var before := amount
	var after: float = 1.0
	breakdown.append({
		"rule": "spectral_physical",
		"before": before,
		"after": after
	})
	return after
