extends Resource
class_name Ability

## Ability - Defines a combat ability with costs, cast time, targeting, and effects
## Abilities are data-driven resources that can be modified by items/passives

enum AbilityType {
	INSTANT,      # Resolves immediately
	DELAYED_CAST, # Resolves after X turns, does nothing until then
	CHANNELED     # Applies effects each turn, can be interrupted
}

enum TargetingType {
	SELF,
	SINGLE_ALLY,
	SINGLE_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	ALL_COMBATANTS,
	RANDOM_ENEMY,
	RANDOM_ALLY
}

## Used with formation + flying: melee respects front-line blocking and cannot hit airborne targets; ranged ignores rows and can hit flyers.
enum AttackRangeProfile {
	MELEE,
	RANGED
}

@export var ability_name: String = ""
@export var ability_id: String = ""
@export var description: String = ""

# Costs & Timing
@export var ap_cost: int = 1
@export var base_cast_time: int = 0  # Turns to resolve (0 = instant)
@export var ability_type: AbilityType = AbilityType.INSTANT

# Targeting
@export var targeting_type: TargetingType = TargetingType.SINGLE_ENEMY
@export var requires_target: bool = true
## Default RANGED so existing abilities stay valid vs flyers until you mark true melee skills in data.
@export var attack_range: AttackRangeProfile = AttackRangeProfile.RANGED

# Effects
@export var effects: Array[AbilityEffect] = []

# Interruption
@export var can_be_interrupted: bool = true

# Channeled behavior: if true, channeled abilities apply their first tick on the turn they're cast
# If false, first tick happens on the caster's next turn (e.g. items can set this to true)
@export var channeled_tick_on_cast: bool = false

## If non-empty, hero must have every [member Weapon.weapon_type_id] listed on equipped weapons (see [method HeroCharacter.ability_allowed_by_equipment]).
@export var required_weapon_type_ids: Array[String] = []
## When true, treated as a weapon-granted basic for one-basic-per-turn rules (enforced in [code]CombatController[/code] in a later step).
@export var is_basic_attack: bool = false

## Physical / magical / true — **summary** for UI, filters, and future traits. **Combat mitigation** still uses each [AbilityEffect]'s [method AbilityEffect.get_effective_damage_kind] when effects resolve. For a single DAMAGE effect, keep this **aligned** with that effect ([member AbilityEffect.damage_kind] + [member AbilityEffect.is_magical]).
@export var primary_damage_kind: CombatDamageKind.Kind = CombatDamageKind.Kind.PHYSICAL

# Modifiers (applied by items/passives at runtime)
# These are dictionaries that modify ability properties
# e.g., {"cast_time": -1, "ap_cost": -1, "potency_multiplier": 1.2}
var runtime_modifiers: Dictionary = {}

## Get the modified cast time based on runtime modifiers
func get_modified_cast_time() -> int:
	var modified_time = base_cast_time
	if runtime_modifiers.has("cast_time"):
		modified_time += runtime_modifiers.cast_time
	return max(0, modified_time)  # Can't be negative

## Get the modified AP cost based on runtime modifiers
func get_modified_ap_cost() -> int:
	var modified_cost = ap_cost
	if runtime_modifiers.has("ap_cost"):
		modified_cost += runtime_modifiers.ap_cost
	return max(0, modified_cost)  # Can't be negative

## Apply runtime modifier from equipment/passive
func apply_modifier(modifier_dict: Dictionary):
	for key in modifier_dict:
		if runtime_modifiers.has(key):
			runtime_modifiers[key] += modifier_dict[key]
		else:
			runtime_modifiers[key] = modifier_dict[key]

## Clear all runtime modifiers (e.g., when equipment changes)
func clear_modifiers():
	runtime_modifiers.clear()


## [enum AbilityEffect.EffectType.DAMAGE] kind of the **first** damage effect; falls back to [member primary_damage_kind] if there is none.
func get_resolved_primary_damage_kind() -> CombatDamageKind.Kind:
	for e in effects:
		if e != null and e.effect_type == AbilityEffect.EffectType.DAMAGE:
			return e.get_effective_damage_kind()
	return primary_damage_kind


## Check if this ability can target the specified target
func can_target(caster_is_player: bool, target_is_player: bool) -> bool:
	match targeting_type:
		TargetingType.SELF:
			return false  # Self-targeting doesn't need validation
		TargetingType.SINGLE_ALLY:
			return caster_is_player == target_is_player
		TargetingType.SINGLE_ENEMY:
			return caster_is_player != target_is_player
		TargetingType.RANDOM_ALLY:
			return caster_is_player == target_is_player
		TargetingType.RANDOM_ENEMY:
			return caster_is_player != target_is_player
		_:
			return true  # AoE abilities don't need target validation


## Mechanics-accurate description generated from ability data and effects.
## Use this for UI panels when you want exact behavior text even if [member description] is flavor-heavy.
func get_player_facing_description() -> String:
	var sentences: Array[String] = []
	for e in effects:
		if e == null:
			continue
		var line := _describe_effect_for_players(e)
		if not line.is_empty():
			sentences.append(line)
	if sentences.is_empty():
		if not description.strip_edges().is_empty():
			sentences.append(description.strip_edges())
		else:
			sentences.append("No effect data configured.")
	var cast_line := _describe_cast_behavior_for_players()
	if not cast_line.is_empty():
		sentences.append(cast_line)
	var joined := ""
	for i in range(sentences.size()):
		if i > 0:
			joined += " "
		joined += sentences[i]
	return joined


func _describe_effect_for_players(effect: AbilityEffect) -> String:
	match effect.effect_type:
		AbilityEffect.EffectType.DAMAGE:
			return "Deal %s %s damage %s." % [
				_format_amount_formula(effect.potency, effect.stat_scaling),
				_damage_kind_to_text(effect.get_effective_damage_kind()),
				_target_phrase()
			]
		AbilityEffect.EffectType.HEAL:
			return "Restore %s health %s." % [
				_format_amount_formula(effect.potency, effect.stat_scaling),
				_target_phrase()
			]
		AbilityEffect.EffectType.APPLY_STATUS:
			var status_text := _status_effect_phrase(effect.status_to_apply)
			return "Apply %s %s." % [status_text, _target_phrase()]
		AbilityEffect.EffectType.INTERRUPT_CAST:
			return "Interrupt active casts %s." % _target_phrase()
		AbilityEffect.EffectType.RESTORE_AP:
			return "Restore AP %s." % _target_phrase()
		AbilityEffect.EffectType.DRAIN_AP:
			return "Drain AP %s." % _target_phrase()
		AbilityEffect.EffectType.SHIELD:
			return "Grant a shield for %s %s." % [
				_format_amount_formula(effect.potency, effect.stat_scaling),
				_target_phrase()
			]
		AbilityEffect.EffectType.DISPEL:
			return "Dispel up to %d status effect%s %s." % [
				maxi(1, effect.dispel_count),
				"" if maxi(1, effect.dispel_count) == 1 else "s",
				_target_phrase()
			]
		AbilityEffect.EffectType.SPAWN:
			return "Spawn %d '%s' unit%s." % [
				maxi(1, effect.spawn_count),
				effect.enemy_to_spawn_id if not effect.enemy_to_spawn_id.is_empty() else "enemy",
				"" if maxi(1, effect.spawn_count) == 1 else "s"
			]
		AbilityEffect.EffectType.LIFESTEAL:
			return "Deal %s damage %s and heal for %d%% of damage dealt." % [
				_format_amount_formula(effect.potency, effect.stat_scaling),
				_target_phrase(),
				int(round(clampf(effect.lifesteal_ratio, 0.0, 1.0) * 100.0))
			]
		AbilityEffect.EffectType.APPLY_GROUNDING:
			var grounding_text := _status_effect_phrase(effect.status_to_apply)
			return "Apply %s to innately flying targets %s, grounding them to the front row." % [grounding_text, _target_phrase()]
		AbilityEffect.EffectType.MOVE_FORMATION:
			match ability_id:
				"advance":
					return "Move from the back row to the front row."
				"retreat":
					return "Move from the front row to the back row."
				_:
					return "Move to the opposite row."
		AbilityEffect.EffectType.PUSH_TO_BACK:
			return "Force targets %s to the back row." % _target_phrase()
		AbilityEffect.EffectType.PULL_TO_FRONT:
			return "Force targets %s to the front row." % _target_phrase()
	return ""


func _describe_cast_behavior_for_players() -> String:
	var cast_turns := get_modified_cast_time()
	match ability_type:
		AbilityType.INSTANT:
			return ""
		AbilityType.DELAYED_CAST:
			if cast_turns <= 0:
				return "Resolves instantly."
			var base := "Resolves after %d turn%s." % [cast_turns, "" if cast_turns == 1 else "s"]
			if can_be_interrupted:
				return base + " Can be interrupted."
			return base + " Cannot be interrupted."
		AbilityType.CHANNELED:
			if cast_turns <= 0:
				return "Channeled effect."
			var start_line := "Channels for %d turn%s." % [cast_turns, "" if cast_turns == 1 else "s"]
			if channeled_tick_on_cast:
				start_line += " First tick resolves immediately on cast."
			else:
				start_line += " First tick resolves on your next turn."
			if can_be_interrupted:
				return start_line + " Can be interrupted."
			return start_line + " Cannot be interrupted."
	return ""


func _format_amount_formula(potency: float, scaling: Dictionary) -> String:
	var terms: Array[String] = []
	if not is_zero_approx(potency):
		terms.append(_format_number(potency))
	for key in scaling.keys():
		var coef := float(scaling[key])
		if is_zero_approx(coef):
			continue
		var stat_name := _combat_stat_key_to_text(str(key))
		terms.append("%sx %s" % [_format_number(coef), stat_name])
	if terms.is_empty():
		return "0"
	var out := terms[0]
	for i in range(1, terms.size()):
		out += " + %s" % terms[i]
	return out


func _target_phrase() -> String:
	match targeting_type:
		TargetingType.SELF:
			return "to yourself"
		TargetingType.SINGLE_ALLY:
			return "to a single ally"
		TargetingType.SINGLE_ENEMY:
			return "to a single enemy"
		TargetingType.ALL_ALLIES:
			return "to all allies"
		TargetingType.ALL_ENEMIES:
			return "to all enemies"
		TargetingType.ALL_COMBATANTS:
			return "to all combatants"
		TargetingType.RANDOM_ENEMY:
			return "to a random enemy"
		TargetingType.RANDOM_ALLY:
			return "to a random ally"
	return "to the target"


func _status_effect_phrase(status: StatusEffect) -> String:
	if status == null:
		return "a status effect"
	var status_name := status.status_name if not status.status_name.is_empty() else "status"
	var turns := maxi(1, status.base_duration)
	return "%s for %d turn%s" % [status_name, turns, "" if turns == 1 else "s"]


func _damage_kind_to_text(kind: CombatDamageKind.Kind) -> String:
	match kind:
		CombatDamageKind.Kind.PHYSICAL:
			return "Physical"
		CombatDamageKind.Kind.MAGICAL:
			return "Magical"
		CombatDamageKind.Kind.TRUE:
			return "True"
	return "Unknown"


func _combat_stat_key_to_text(key: String) -> String:
	match key:
		"atk":
			return "Attack"
		"def":
			return "Defense"
		"spd":
			return "Speed"
		"mag":
			return "Magic"
		"mag_def":
			return "Magic Defense"
		"strength":
			return "Strength"
		"agility":
			return "Agility"
		"constitution":
			return "Constitution"
		"intellect":
			return "Intellect"
		"spirit":
			return "Spirit"
		"charisma":
			return "Charisma"
		"luck":
			return "Luck"
	return key


func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snappedf(value, 0.01))
