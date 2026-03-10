extends Resource
class_name AbilityEffect

## AbilityEffect - Defines a single effect that an ability produces
## Effects can be damage, healing, status application, interrupts, spawns, etc.

enum EffectType {
	DAMAGE,          ## 0 — deal damage to target
	HEAL,            ## 1 — restore health to target
	APPLY_STATUS,    ## 2 — apply a StatusEffect to target
	INTERRUPT_CAST,  ## 3 — interrupt target's current cast
	RESTORE_AP,      ## 4 — restore action points
	DRAIN_AP,        ## 5 — drain action points
	SHIELD,          ## 6 — apply a damage-absorbing shield
	DISPEL,          ## 7 — remove active statuses from target
	SPAWN,           ## 8 — spawn a new enemy combatant
	LIFESTEAL        ## 9 — deal damage and heal caster for a portion
}

@export var effect_type: EffectType = EffectType.DAMAGE
@export var potency: float = 0.0     ## Base damage/heal/shield amount
@export var stat_scaling: Dictionary = {}  ## e.g. {"atk": 1.0} — adds stat × factor to potency
@export var target_count: int = 1    ## Targets hit (use 999 for all)
@export var status_to_apply: StatusEffect = null  ## Required when effect_type == APPLY_STATUS

## DISPEL
@export var dispel_count: int = 1

## SPAWN — enemy_to_spawn_id must match an enemy resource enemy_id
@export var enemy_to_spawn_id: String = ""
@export var spawn_count: int = 1

## LIFESTEAL — fraction of damage dealt returned as healing to the caster (0.0–1.0)
@export var lifesteal_ratio: float = 0.5

## When true, damage from this effect reduces mag_def instead of def
@export var is_magical: bool = false

## Calculate final potency based on caster's core_stats dictionary
func calculate_final_potency(caster_stats: Dictionary) -> float:
	var final_potency := potency
	for stat_name in stat_scaling:
		if caster_stats.has(stat_name):
			final_potency += float(caster_stats[stat_name]) * stat_scaling[stat_name]
	return final_potency
