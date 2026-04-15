extends RefCounted
class_name CombatDamageResolver

## Single entry point for computing how much damage reaches shields/HP after stat mitigation and
## creature-tag rules. Shields and final HP reduction happen in CombatantStats.apply_resolved_hit.

static func resolve_incoming(target: CombatantData, packet: DamagePacket) -> Dictionary:
	var amount: float = packet.base_amount
	var breakdown: Array = []

	if amount <= 0.0:
		return {
			"final_amount": 0.0,
			"breakdown": breakdown
		}

	match packet.category:
		CombatDamageKind.Kind.TRUE:
			breakdown.append({
				"step": "true_damage",
				"amount": amount
			})
			# Tag rules may still apply for special cases; add explicit branches in CreatureTagDamageRules.
			amount = CreatureTagDamageRules.apply_after_stat_mitigation(target, CombatDamageKind.Kind.TRUE, amount, breakdown)

		CombatDamageKind.Kind.PHYSICAL:
			if not packet.bypass_physical_mitigation:
				var def_val: int = target.combatant_stats.get_effective_stat("def")
				var before_stat: float = amount
				amount = max(0.0, amount - float(def_val))
				breakdown.append({
					"step": "physical_mitigation",
					"stat": "def",
					"value": def_val,
					"before": before_stat,
					"after": amount
				})
			else:
				breakdown.append({
					"step": "physical_bypass_armour",
					"amount": amount
				})
			amount = CreatureTagDamageRules.apply_after_stat_mitigation(target, CombatDamageKind.Kind.PHYSICAL, amount, breakdown)

		CombatDamageKind.Kind.MAGICAL:
			var md: int = target.combatant_stats.get_effective_stat("mag_def")
			var before_mag: float = amount
			amount = max(0.0, amount - float(md))
			breakdown.append({
				"step": "magical_mitigation",
				"stat": "mag_def",
				"value": md,
				"before": before_mag,
				"after": amount
			})
			amount = CreatureTagDamageRules.apply_after_stat_mitigation(target, CombatDamageKind.Kind.MAGICAL, amount, breakdown)

	return {
		"final_amount": max(0.0, amount),
		"breakdown": breakdown
	}
