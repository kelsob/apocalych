extends RefCounted
class_name CombatantData

## CombatantData - Runtime wrapper that connects HeroCharacter/Enemy to combat systems
## Provides a unified interface for combat logic regardless of combatant source

signal turn_started()
signal ability_cast(ability: Ability, targets: Array)
signal took_damage(amount: float, source: CombatantData)
signal died()

# Source reference (HeroCharacter or Enemy resource)
var source: Variant = null
var is_player: bool = false

# Combat stats
var combatant_stats: CombatantStats = null

# Available abilities
var abilities: Array[Ability] = []

## Set true after this combatant uses a basic ([member Ability.is_basic_attack]) this turn; cleared in [method start_turn].
var basic_attack_used_this_turn: bool = false

# Combat state
var display_name: String = ""
var is_dead: bool = false
var current_target: CombatantData = null

# Timeline tracking
var next_turn_time: float = 0.0
var turn_count: int = 0

const STATUS_ID_GROUNDED := "grounded"
const ABILITY_ID_MOVE := "move"
const ABILITY_ID_ADVANCE := "advance"
const ABILITY_ID_RETREAT := "retreat"
const ABILITY_ID_BASIC_ATTACK := "basic_attack"
const ADVANCE_ABILITY_PATH := "res://resources/abilities/shared/advance.tres"
const RETREAT_ABILITY_PATH := "res://resources/abilities/shared/retreat.tres"

static var _advance_ability_cache: Ability = null
static var _retreat_ability_cache: Ability = null

enum PreferredFormation {
	FRONT,
	BACK,
	INDIFFERENT
}

## Front / back — who blocks melee on this side of the fight (runtime; can change when grounded).
var formation_row: CombatRow.Kind = CombatRow.Kind.FRONT
## Snapshot from hero/enemy resource at combat start; restored when [const STATUS_ID_GROUNDED] expires.
var formation_row_base: CombatRow.Kind = CombatRow.Kind.FRONT
## Enemies: where AI tries to stand (heroes default to INDIFFERENT).
var preferred_formation: PreferredFormation = PreferredFormation.INDIFFERENT

## Initialize from a HeroCharacter
func initialize_from_hero_character(member: HeroCharacter):
	source = member
	is_player = true
	display_name = member.member_name
	
	# Create and initialize combat stats
	combatant_stats = CombatantStats.new()
	combatant_stats.initialize_from_hero_character(member)
	combatant_stats.combatant_owner = self
	
	# Connect signals
	combatant_stats.died.connect(_on_died)
	combatant_stats.status_removed.connect(_on_status_removed)
	
	# Load abilities: hero's unlocked class specials, strip class-defined basics/move legacy ids, weapon-granted basics first, gear filter, movement defaults/overrides
	member.ensure_unlocked_combat_abilities_initialized()
	_load_class_specials_from_hero(member)
	_strip_class_basics_for_weapon_grants()
	_prepend_weapon_granted_abilities(member)
	_filter_abilities_by_equipment(member)
	_remove_legacy_move_ability()
	_ensure_movement_abilities_for_hero(member)
	
	var row_i: int = member.resolve_initial_formation_row()
	assert(row_i == 0 or row_i == 1, "combat positioning: '%s' resolved invalid row index %d (expected 0=Front, 1=Back)" % [display_name, row_i])
	formation_row = CombatRow.Kind.FRONT if row_i == 0 else CombatRow.Kind.BACK
	formation_row_base = formation_row
	print("combat positioning: CombatantData init player '%s' formation_row=%s (resolved_index=%d)" % [display_name, "FRONT" if formation_row == CombatRow.Kind.FRONT else "BACK", row_i])
	
	# Calculate first turn time (will be set by CombatTimeline)
	next_turn_time = 0.0

## Initialize from an Enemy resource
func initialize_from_enemy(enemy: Enemy):
	source = enemy
	is_player = false
	display_name = enemy.enemy_name
	
	# Create combat stats from enemy definition
	combatant_stats = enemy.create_combat_stats()
	combatant_stats.combatant_owner = self
	
	# Connect signals
	combatant_stats.died.connect(_on_died)
	combatant_stats.status_removed.connect(_on_status_removed)
	
	# Copy abilities
	abilities = enemy.abilities.duplicate()
	_remove_legacy_move_ability()
	_ensure_movement_abilities_for_enemy(enemy)
	
	match enemy.preferred_zone:
		0:
			preferred_formation = PreferredFormation.FRONT
		1:
			preferred_formation = PreferredFormation.BACK
		_:
			preferred_formation = PreferredFormation.INDIFFERENT
	
	formation_row = CombatRow.Kind.FRONT if enemy.formation_row == 0 else CombatRow.Kind.BACK
	formation_row_base = formation_row
	
	# Calculate first turn time (will be set by CombatTimeline)
	next_turn_time = 0.0


## Heroes: colour from hero class. Enemies: neutral UI tint until enemy resources define accents.
func get_display_class_color() -> Color:
	if is_player and source is HeroCharacter:
		return (source as HeroCharacter).get_class_color()
	return Color(0.78, 0.76, 0.74, 1.0)


## Class specials for this hero (see [member HeroCharacter.unlocked_combat_abilities]).
func _load_class_specials_from_hero(member: HeroCharacter) -> void:
	abilities.clear()
	for a in member.unlocked_combat_abilities:
		if a != null:
			abilities.append(a)


func _strip_class_basics_for_weapon_grants() -> void:
	for i in range(abilities.size() - 1, -1, -1):
		var a: Ability = abilities[i]
		if a == null:
			continue
		if a.is_basic_attack or a.ability_id == ABILITY_ID_BASIC_ATTACK:
			abilities.remove_at(i)


func _prepend_weapon_granted_abilities(member: HeroCharacter) -> void:
	var seen: Dictionary = {}
	var weapon_first: Array[Ability] = []
	for w in member.get_all_equipped_weapons():
		if w == null:
			continue
		for g in w.granted_basic_attacks:
			if g == null:
				continue
			var key: String = g.ability_id if not g.ability_id.is_empty() else str(g.resource_path)
			if seen.has(key):
				continue
			seen[key] = true
			weapon_first.append(g)
	for a in abilities:
		if a == null:
			continue
		var k: String = a.ability_id if not a.ability_id.is_empty() else str(a.resource_path)
		if seen.has(k):
			continue
		seen[k] = true
		weapon_first.append(a)
	abilities = weapon_first


func _filter_abilities_by_equipment(member: HeroCharacter) -> void:
	var filtered: Array[Ability] = []
	for a in abilities:
		if a == null:
			continue
		if member.ability_allowed_by_equipment(a):
			filtered.append(a)
	abilities = filtered


## Start a turn for this combatant
## Returns status effect processing results
func start_turn() -> Dictionary:
	basic_attack_used_this_turn = false
	turn_count += 1
	
	# Process status effects FIRST (poison damages, regen heals, etc.)
	var status_results = combatant_stats.process_status_effects()
	
	# Regenerate AP (even if stunned)
	combatant_stats.regenerate_ap()
	
	# Emit signal
	turn_started.emit()
	
	return status_results

## Heroes: gear satisfies [member Ability.required_weapon_type_ids]. Enemies: always true.
func is_ability_usable_with_current_gear(ability: Ability) -> bool:
	if ability == null:
		return false
	if not is_player or source == null:
		return true
	if source is HeroCharacter:
		return (source as HeroCharacter).ability_allowed_by_equipment(ability)
	return true


## False if gear forbids this ability or a basic was already used this turn.
func can_cast_ability_this_turn(ability: Ability) -> bool:
	if ability == null:
		return false
	if not is_ability_usable_with_current_gear(ability):
		return false
	if not is_ability_contextually_available(ability):
		return false
	if ability.is_basic_attack and basic_attack_used_this_turn:
		return false
	return true


## Cast an ability at target(s)
func cast_ability(ability: Ability, targets: Array) -> bool:
	# Check if can act
	if not combatant_stats.can_act():
		return false
	
	# Check if can cast
	if not combatant_stats.can_cast():
		return false
	
	if is_movement_ability(ability) and not can_use_formation_move():
		push_warning("%s cannot change row while grounded." % display_name)
		return false
	if not is_ability_contextually_available(ability):
		push_warning("%s cannot use %s from current row." % [display_name, ability.ability_name])
		return false
	
	# Check AP cost
	var ap_cost = ability.get_modified_ap_cost()
	if not combatant_stats.spend_ap(ap_cost):
		return false
	
	# Emit signal
	ability_cast.emit(ability, targets)
	
	return true

## Apply damage using the full pipeline (mitigation, creature tags, shields, HP).
func apply_incoming_damage(packet: DamagePacket, source_combatant: CombatantData = null) -> Dictionary:
	var resolved: Dictionary = CombatDamageResolver.resolve_incoming(self, packet)
	var damage_result: Dictionary = combatant_stats.apply_resolved_hit(resolved.final_amount)
	damage_result["breakdown"] = resolved.breakdown
	took_damage.emit(packet.base_amount, source_combatant)
	return damage_result


## Back-compat: raw physical hit with full def mitigation (no packet).
func take_damage(amount: float, source_combatant: CombatantData = null, packet: DamagePacket = null) -> Dictionary:
	if packet != null:
		return apply_incoming_damage(packet, source_combatant)
	return apply_incoming_damage(DamagePacket.physical_simple(amount), source_combatant)

## Sync combat state back to source (called after combat ends)
func sync_back_to_source():
	if source is HeroCharacter:
		source.current_health = combatant_stats.current_health
		# Could sync other persistent effects here (e.g., permanent stat changes)

## Get effective initiative value for the timeline (same as legacy name [code]get_effective_speed[/code] on stats).
func get_effective_speed() -> float:
	return combatant_stats.get_effective_speed()

## Check if this combatant can be targeted
func can_be_targeted() -> bool:
	return not is_dead


func is_stealthed() -> bool:
	return combatant_stats.has_status_id("stealth")


## True if this unit has the flying tag (ignores grounded). Used for grounding abilities.
func innately_flying() -> bool:
	if source is Enemy:
		var e: Enemy = source as Enemy
		return (e.get_creature_tag_mask() & Enemy.TAG_FLYING) != 0
	return false


## Airborne targets can only be damaged by ranged abilities while flying; grounded status negates.
func is_effective_flying() -> bool:
	if combatant_stats.has_status_id(STATUS_ID_GROUNDED):
		return false
	return innately_flying()


## Called when a grounding ability applies [const STATUS_ID_GROUNDED] to an innate flyer.
func apply_grounding_formation():
	formation_row = CombatRow.Kind.FRONT


func restore_formation_row_after_grounded():
	formation_row = formation_row_base


func can_use_formation_move() -> bool:
	return not combatant_stats.has_status_id(STATUS_ID_GROUNDED)


func is_movement_ability(ability: Ability) -> bool:
	if ability == null:
		return false
	return ability.ability_id == ABILITY_ID_ADVANCE or ability.ability_id == ABILITY_ID_RETREAT or ability.ability_id == ABILITY_ID_MOVE


func is_ability_contextually_available(ability: Ability) -> bool:
	if ability == null:
		return false
	if not is_movement_ability(ability):
		return true
	if not can_use_formation_move():
		return false
	match ability.ability_id:
		ABILITY_ID_ADVANCE:
			return formation_row == CombatRow.Kind.BACK
		ABILITY_ID_RETREAT:
			return formation_row == CombatRow.Kind.FRONT
		ABILITY_ID_MOVE:
			return true
	return true


func swap_formation_row() -> void:
	if formation_row == CombatRow.Kind.FRONT:
		formation_row = CombatRow.Kind.BACK
	else:
		formation_row = CombatRow.Kind.FRONT
	formation_row_base = formation_row


## Forced reposition (push/pull abilities). Updates base row like voluntary move. Allowed while grounded.
func force_to_back_row() -> void:
	if formation_row == CombatRow.Kind.BACK:
		return
	formation_row = CombatRow.Kind.BACK
	formation_row_base = formation_row


func force_to_front_row() -> void:
	if formation_row == CombatRow.Kind.FRONT:
		return
	formation_row = CombatRow.Kind.FRONT
	formation_row_base = formation_row


## AI uses contextual movement (Advance/Retreat) only when this is true.
func wants_ai_to_reposition() -> bool:
	if preferred_formation == PreferredFormation.INDIFFERENT:
		return false
	if not can_use_formation_move():
		return false
	match preferred_formation:
		PreferredFormation.FRONT:
			return formation_row != CombatRow.Kind.FRONT
		PreferredFormation.BACK:
			return formation_row != CombatRow.Kind.BACK
	return false


func desired_reposition_ability_id() -> String:
	match preferred_formation:
		PreferredFormation.FRONT:
			return ABILITY_ID_ADVANCE
		PreferredFormation.BACK:
			return ABILITY_ID_RETREAT
		_:
			return ""


func _remove_legacy_move_ability() -> void:
	for i in range(abilities.size() - 1, -1, -1):
		var a: Ability = abilities[i]
		if a == null:
			continue
		if a.ability_id == ABILITY_ID_MOVE:
			abilities.remove_at(i)


func _ensure_movement_abilities_for_hero(member: HeroCharacter) -> void:
	var existing: Dictionary = {}
	for a in abilities:
		if a != null:
			existing[a.ability_id] = a
	var advance: Ability = existing.get(ABILITY_ID_ADVANCE, null)
	var retreat: Ability = existing.get(ABILITY_ID_RETREAT, null)
	if member.race:
		if member.race.default_advance_ability_override != null:
			advance = member.race.default_advance_ability_override
		if member.race.default_retreat_ability_override != null:
			retreat = member.race.default_retreat_ability_override
	if member.class_resource:
		if member.class_resource.default_advance_ability_override != null:
			advance = member.class_resource.default_advance_ability_override
		if member.class_resource.default_retreat_ability_override != null:
			retreat = member.class_resource.default_retreat_ability_override
	if advance == null:
		advance = _get_default_advance_ability()
	if retreat == null:
		retreat = _get_default_retreat_ability()
	var movement_ap_modifier: int = 0
	if member.race:
		movement_ap_modifier += member.race.movement_ap_cost_modifier
	if member.class_resource:
		movement_ap_modifier += member.class_resource.movement_ap_cost_modifier
	_replace_or_append_movement_ability(ABILITY_ID_ADVANCE, _clone_movement_ability(advance, movement_ap_modifier))
	_replace_or_append_movement_ability(ABILITY_ID_RETREAT, _clone_movement_ability(retreat, movement_ap_modifier))


func _ensure_movement_abilities_for_enemy(enemy: Enemy) -> void:
	var existing: Dictionary = {}
	for a in abilities:
		if a != null:
			existing[a.ability_id] = a
	var advance: Ability = existing.get(ABILITY_ID_ADVANCE, null)
	var retreat: Ability = existing.get(ABILITY_ID_RETREAT, null)
	if enemy.default_advance_ability_override != null:
		advance = enemy.default_advance_ability_override
	if enemy.default_retreat_ability_override != null:
		retreat = enemy.default_retreat_ability_override
	if advance == null:
		advance = _get_default_advance_ability()
	if retreat == null:
		retreat = _get_default_retreat_ability()
	_replace_or_append_movement_ability(ABILITY_ID_ADVANCE, _clone_movement_ability(advance, enemy.movement_ap_cost_modifier))
	_replace_or_append_movement_ability(ABILITY_ID_RETREAT, _clone_movement_ability(retreat, enemy.movement_ap_cost_modifier))


func _replace_or_append_movement_ability(ability_id: String, ability_to_set: Ability) -> void:
	if ability_to_set == null:
		return
	for i in range(abilities.size()):
		var ab: Ability = abilities[i]
		if ab == null:
			continue
		if ab.ability_id == ability_id:
			abilities[i] = ability_to_set
			return
	abilities.append(ability_to_set)


func _clone_movement_ability(base_ability: Ability, ap_cost_modifier: int) -> Ability:
	if base_ability == null:
		return null
	var out: Ability = base_ability.duplicate(true)
	out.clear_modifiers()
	if ap_cost_modifier != 0:
		out.apply_modifier({"ap_cost": ap_cost_modifier})
	return out


func _get_default_advance_ability() -> Ability:
	if _advance_ability_cache == null:
		if not ResourceLoader.exists(ADVANCE_ABILITY_PATH):
			push_warning("CombatantData: Advance ability missing at %s" % ADVANCE_ABILITY_PATH)
			return null
		var loaded = load(ADVANCE_ABILITY_PATH)
		if loaded is Ability:
			_advance_ability_cache = loaded
		else:
			push_warning("CombatantData: %s is not an Ability" % ADVANCE_ABILITY_PATH)
			return null
	return _advance_ability_cache


func _get_default_retreat_ability() -> Ability:
	if _retreat_ability_cache == null:
		if not ResourceLoader.exists(RETREAT_ABILITY_PATH):
			push_warning("CombatantData: Retreat ability missing at %s" % RETREAT_ABILITY_PATH)
			return null
		var loaded = load(RETREAT_ABILITY_PATH)
		if loaded is Ability:
			_retreat_ability_cache = loaded
		else:
			push_warning("CombatantData: %s is not an Ability" % RETREAT_ABILITY_PATH)
			return null
	return _retreat_ability_cache


func _on_status_removed(status: StatusEffect):
	if status.status_id == STATUS_ID_GROUNDED:
		restore_formation_row_after_grounded()

## Called when combatant dies
func _on_died():
	is_dead = true
	died.emit()
