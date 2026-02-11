extends Resource
class_name AbilityEffect

## AbilityEffect - Defines a single effect that an ability produces
## Effects can be damage, healing, status application, interrupts, etc.

enum EffectType {
	DAMAGE,
	HEAL,
	APPLY_STATUS,
	INTERRUPT_CAST,
	RESTORE_AP,
	DRAIN_AP,
	SHIELD,
	DISPEL
}

@export var effect_type: EffectType = EffectType.DAMAGE
@export var potency: float = 0.0  # Base damage/heal/shield amount
@export var stat_scaling: Dictionary = {}  # e.g., {"intelligence": 0.5} means +50% potency per int point above 10
@export var target_count: int = 1  # How many targets this effect hits (for AoE)
@export var status_to_apply: StatusEffect = null  # If effect_type is APPLY_STATUS
@export var dispel_count: int = 1  # Number of statuses to remove if DISPEL

## Calculate final effect potency based on caster stats
func calculate_final_potency(caster_stats: Dictionary) -> float:
	var final_potency = potency
	
	for stat_name in stat_scaling:
		if caster_stats.has(stat_name):
			var stat_value = caster_stats[stat_name]
			var stat_modifier = (stat_value - 10) * 0.5  # D&D style: 10 = baseline, each 2 points = +1 modifier
			var scaling_factor = stat_scaling[stat_name]
			final_potency += stat_modifier * scaling_factor
	
	return final_potency
