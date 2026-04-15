extends RefCounted
class_name CombatTargetRules

## Formation, stealth, and airborne checks for who can be selected by an ability.
## Ally-targeting and self are not restricted by rows. Opponents are filtered by [member Ability.attack_range].

static func ability_uses_opponent_formation_rules(ability: Ability) -> bool:
	match ability.targeting_type:
		Ability.TargetingType.SINGLE_ENEMY, Ability.TargetingType.ALL_ENEMIES, Ability.TargetingType.RANDOM_ENEMY:
			return true
		_:
			return false


static func is_opponent_of(a: CombatantData, b: CombatantData) -> bool:
	return a.is_player != b.is_player


static func filter_by_attack_profile(
	caster: CombatantData,
	ability: Ability,
	candidates: Array,
	player_combatants: Array,
	enemy_combatants: Array
) -> Array:
	if not ability_uses_opponent_formation_rules(ability):
		return candidates
	var out: Array = []
	for t in candidates:
		if t is CombatantData and can_select_opponent(caster, ability, t as CombatantData, player_combatants, enemy_combatants):
			out.append(t)
	return out


static func can_select_opponent(
	caster: CombatantData,
	ability: Ability,
	target: CombatantData,
	player_combatants: Array,
	enemy_combatants: Array
) -> bool:
	if not is_opponent_of(caster, target):
		return true
	if ability.attack_range == Ability.AttackRangeProfile.RANGED:
		return true
	return can_melee_reach(caster, target, player_combatants, enemy_combatants)


static func can_melee_reach(
	caster: CombatantData,
	target: CombatantData,
	player_combatants: Array,
	enemy_combatants: Array
) -> bool:
	if target.is_effective_flying():
		return false
	if caster.is_stealthed():
		return true
	if target.formation_row != CombatRow.Kind.BACK:
		return true
	return not _team_has_other_front_alive(target, player_combatants, enemy_combatants)


static func _team_has_other_front_alive(target: CombatantData, player_combatants: Array, enemy_combatants: Array) -> bool:
	var team: Array = player_combatants if target.is_player else enemy_combatants
	for c in team:
		if not c is CombatantData:
			continue
		var cd: CombatantData = c as CombatantData
		if cd.is_dead or cd == target:
			continue
		if cd.formation_row == CombatRow.Kind.FRONT:
			return true
	return false
